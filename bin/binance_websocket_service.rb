#!/usr/bin/env ruby
require 'websocket-client-simple'
require 'json'
require 'time'
require 'net/http'
require 'set'
require 'logger' # Für bessere Protokollierung
require 'concurrent' # Für Concurrent-Programmierung, z.B. Timer
require_relative '../config/environment' # Rails-Umgebung laden (stellt Cryptocurrency und CryptoHistoryData bereit)

# Test-Ausgabe beim Laden der Datei (nur für Debugging)
Rails.logger.info "🔧 WebSocket Service Datei wird geladen..." if defined?(Rails.logger)
Rails.logger.info "🔧 ENV DEBUG_MODE: #{ENV.fetch('DEBUG_MODE', 'not_set')}" if defined?(Rails.logger)
Rails.logger.info "🔧 ENV VERBOSE_LOGGING: #{ENV.fetch('VERBOSE_LOGGING', 'not_set')}" if defined?(Rails.logger)

# --- Debug-Konfiguration ---
# Setze auf false, um detaillierte Logs zu deaktivieren (bessere Performance)
DEBUG_MODE = ENV.fetch('DEBUG_MODE', 'false').downcase == 'true'
VERBOSE_LOGGING = ENV.fetch('VERBOSE_LOGGING', 'false').downcase == 'true'

# Hilfsfunktion für bedingte Logs
def debug_log(message)
  Rails.logger.debug(message) if DEBUG_MODE && Rails.logger
end

def verbose_log(message)
  Rails.logger.info(message) if VERBOSE_LOGGING && Rails.logger
end

# --- Konfiguration und Konstanten ---
BINANCE_WS_BASE_URL = "wss://stream.binance.com:9443/ws"
BINANCE_REST_API_BASE_URL = "https://api.binance.com/api/v3"
PING_INTERVAL_SECONDS = 30 # Sekunden: Wie oft wir einen Ping senden (Binance-Empfehlung ca. alle 3 Minuten, aber aggressiver ist sicherer)
PONG_TIMEOUT_SECONDS = 60 # Sekunden: Reduziert auf 60 Sekunden für schnellere Reconnects
RECONNECT_INITIAL_DELAY_SECONDS = 2 # Sekunden: Schnellere Reconnects
RECONNECT_MAX_DELAY_SECONDS = 30 # Sekunden: Maximale Verzögerung für exponentiellen Backoff
MAX_RECONNECT_ATTEMPTS = 10 # Maximale Anzahl Reconnect-Versuche vor Pause

# --- Market Cap Update Intervall ---
MARKET_CAP_UPDATE_INTERVAL = 300 # 5 Minuten: Wie oft Market Cap Daten aktualisiert werden

# --- Connection Pool Management ---
# Optimiertes Connection Pool Management für PostgreSQL (Multi-Threading fähig)
def with_database_connection
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    begin
      yield
    rescue ActiveRecord::ConnectionTimeoutError => e
      Rails.logger.error "❌ Connection Pool Timeout: #{e.message}"
      # PostgreSQL kann mehr Verbindungen handhaben, also weniger aggressive Retry-Logik
      sleep 0.05
      retry
    rescue PG::ConnectionBad, PG::UnableToSend => e
      Rails.logger.error "❌ PostgreSQL Verbindungsfehler: #{e.message}"
      # Versuche Verbindung wiederherzustellen
      connection.reconnect! if connection.respond_to?(:reconnect!)
      retry
    rescue => e
      Rails.logger.error "❌ Datenbankfehler: #{e.class} - #{e.message}"
      raise e
    end
  end
end

# --- Logger-Konfiguration ---
# Verwende Rails.logger statt eigener Logger-Konstante



# --- Hilfsfunktion: Lese und filtere Paare aus bot.json ---
# Diese Klasse ist für das Laden und Filtern der Handelspaare zuständig.
class PairSelector
  # Lädt die Paare aus der bot.json und filtert diese.
  def self.load_pairs
    config_path = File.join(__dir__, '../config/bot.json')
    unless File.exist?(config_path)
      Rails.logger.error "Konfigurationsdatei nicht gefunden: #{config_path}"
      raise "Konfigurationsdatei bot.json nicht gefunden. Bitte stellen Sie sicher, dass sie im 'config'-Verzeichnis liegt."
    end

    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    blacklist = config.dig('exchange', 'pair_blacklist') || []

    Rails.logger.info "Lade aktive Trading-Paare von Binance API..."
    uri = URI(BINANCE_REST_API_BASE_URL + "/exchangeInfo")
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Fehler beim Laden der Binance-Paare: #{response.code} - #{response.message}"
      raise "Fehler beim Laden der Binance-Paare: #{response.code} #{response.message}"
    end

    data = JSON.parse(response.body)
    symbols = data['symbols']

    active_pairs = symbols.select { |s| s['status'] == 'TRADING' }

    # Whitelist-Filterung: Erlaubt explizite Paare oder Regex-Muster
    if whitelist.any?
      if whitelist.any? { |w| w.include?('.*') || w.include?('*') } # Prüfen auf Regex-Muster
        regexes = whitelist.map { |w| Regexp.new(w.gsub('/', '').gsub('*', '.*'), Regexp::IGNORECASE) }
        active_pairs = active_pairs.select { |s| regexes.any? { |r| s['symbol'] =~ r } }
        verbose_log "Whitelist (Regex) angewendet: #{whitelist.inspect}"
      else # Explizite Paare
        allowed_symbols = whitelist.map { |p| p.gsub('/', '').upcase }.to_set
        active_pairs = active_pairs.select { |s| allowed_symbols.include?(s['symbol'].upcase) }
        verbose_log "Whitelist (explizit) angewendet: #{whitelist.inspect}"
      end
    else
      Rails.logger.warn "Keine Whitelist konfiguriert. Alle TRADING-Paare werden berücksichtigt."
    end

    # Blacklist-Filterung: Entfernt unerwünschte Paare
    if blacklist.any?
      blocked_symbols = blacklist.map { |p| p.gsub('/', '').upcase }.to_set
      active_pairs = active_pairs.reject { |s| blocked_symbols.include?(s['symbol'].upcase) }
      verbose_log "Blacklist angewendet: #{blacklist.inspect}"
    end

    selected_pairs = active_pairs.map { |s| s['symbol'].downcase }
    Rails.logger.info "Ausgewählte Paare für den Stream: #{selected_pairs.join(', ')} (#{selected_pairs.length} Paare)"
    selected_pairs
  end
end

# --- Market Cap Service ---
# Diese Klasse ist für das Laden von Market Cap Daten von der CoinGecko API zuständig.
class MarketCapService
  def self.fetch_market_cap_data
    Rails.logger.info "📊 Lade Market Cap Daten von CoinGecko API..."
    
    begin
      # Lade Konfiguration für Symbol-Mapping
      config_path = File.join(__dir__, '../config/bot.json')
      config = JSON.parse(File.read(config_path))
      whitelist = config.dig('exchange', 'pair_whitelist') || []
      
      # Erstelle Mapping von Binance-Symbolen zu CoinGecko-IDs
      symbol_mapping = create_symbol_mapping(whitelist)
      
      # Hole Market Cap Daten von CoinGecko für alle relevanten Coins
      # Verwende die CoinGecko-IDs (Values), nicht die Binance-Symbole (Keys)
      coin_gecko_ids = symbol_mapping.values.uniq
      coin_data = fetch_coin_data_from_coingecko(coin_gecko_ids)
      
      if coin_data.empty?
        Rails.logger.warn "⚠️ Keine CoinGecko Daten erhalten"
        return
      end
      
      Rails.logger.info "📊 Verarbeite #{coin_data.length} Coins für Market Cap Update"
      
      # Aktualisiere die Datenbank
      update_market_cap_in_database(coin_data, symbol_mapping)
      
      Rails.logger.info "✅ Market Cap Daten erfolgreich aktualisiert"
      
    rescue => e
      Rails.logger.error "❌ Fehler beim Laden der Market Cap Daten: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  def self.create_symbol_mapping(whitelist)
    # Mapping von Binance-Symbolen zu CoinGecko-IDs
    # Beispiel: BTCUSDC -> bitcoin, ETHUSDC -> ethereum
    mapping = {}
    
    whitelist.each do |pair|
      # Entferne USDC und konvertiere zu CoinGecko-Format
      base_currency = pair.gsub('/USDC', '').downcase
      
      # Spezielle Mapping-Regeln für CoinGecko
      case base_currency
      when 'btc'
        mapping['BTCUSDC'] = 'bitcoin'
      when 'eth'
        mapping['ETHUSDC'] = 'ethereum'
      when 'bnb'
        mapping['BNBUSDC'] = 'binancecoin'
      when 'ada'
        mapping['ADAUSDC'] = 'cardano'
      when 'sol'
        mapping['SOLUSDC'] = 'solana'
      when 'dot'
        mapping['DOTUSDC'] = 'polkadot'
      when 'link'
        mapping['LINKUSDC'] = 'chainlink'
      when 'uni'
        mapping['UNIUSDC'] = 'uniswap'
      when 'matic'
        mapping['MATICUSDC'] = 'matic-network'
      when 'ltc'
        mapping['LTCUSDC'] = 'litecoin'
      when 'xrp'
        mapping['XRPUSDC'] = 'ripple'
      when 'avax'
        mapping['AVAXUSDC'] = 'avalanche-2'
      when 'atom'
        mapping['ATOMUSDC'] = 'cosmos'
      when 'etc'
        mapping['ETCUSDC'] = 'ethereum-classic'
      when 'fil'
        mapping['FILUSDC'] = 'filecoin'
      when 'vet'
        mapping['VETUSDC'] = 'vechain'
      when 'icp'
        mapping['ICPUSDC'] = 'internet-computer'
      when 'apt'
        mapping['APTUSDC'] = 'aptos'
      when 'near'
        mapping['NEARUSDC'] = 'near'
      when 'algo'
        mapping['ALGOUSDC'] = 'algorand'
      when 'hbar'
        mapping['HBARUSDC'] = 'hedera-hashgraph'
      when 'sand'
        mapping['SANDUSDC'] = 'the-sandbox'
      when 'mana'
        mapping['MANAUSDC'] = 'decentraland'
      when 'enj'
        mapping['ENJUSDC'] = 'enjincoin'
      when 'gala'
        mapping['GALAUSDC'] = 'gala'
      when 'chz'
        mapping['CHZUSDC'] = 'chiliz'
      when 'hot'
        mapping['HOTUSDC'] = 'holochain'
      when 'bat'
        mapping['BATUSDC'] = 'basic-attention-token'
      when 'zil'
        mapping['ZILUSDC'] = 'zilliqa'
      when 'one'
        mapping['ONEUSDC'] = 'harmony'
      when 'doge'
        mapping['DOGEUSDC'] = 'dogecoin'
      when 'shib'
        mapping['SHIBUSDC'] = 'shiba-inu'
      when 'trx'
        mapping['TRXUSDC'] = 'tron'
      when 'eos'
        mapping['EOSUSDC'] = 'eos'
      when 'neo'
        mapping['NEOUSDC'] = 'neo'
      when 'xlm'
        mapping['XLMUSDC'] = 'stellar'
      when 'xmr'
        mapping['XMRUSDC'] = 'monero'
      when 'dash'
        mapping['DASHUSDC'] = 'dash'
      when 'zec'
        mapping['ZECUSDC'] = 'zcash'
      when 'bch'
        mapping['BCHUSDC'] = 'bitcoin-cash'
      when 'bsv'
        mapping['BSVUSDC'] = 'bitcoin-sv'
      when 'btg'
        mapping['BTGUSDC'] = 'bitcoin-gold'
      when 'btt'
        mapping['BTTUSDC'] = 'bittorrent'
      when 'win'
        mapping['WINUSDC'] = 'wink'
      when 'cake'
        mapping['CAKEUSDC'] = 'pancakeswap-token'
      when 'sxp'
        mapping['SXPUSDC'] = 'sxp'
      when 'comp'
        mapping['COMPUSDC'] = 'compound-governance-token'
      when 'aave'
        mapping['AAVEUSDC'] = 'aave'
      when 'mkr'
        mapping['MKRUSDC'] = 'maker'
      when 'yfi'
        mapping['YFIUSDC'] = 'yearn-finance'
      when 'sushi'
        mapping['SUSHIUSDC'] = 'sushi'
      when '1inch'
        mapping['1INCHUSDC'] = '1inch'
      when 'crv'
        mapping['CRVUSDC'] = 'curve-dao-token'
      when 'snx'
        mapping['SNXUSDC'] = 'havven'
      when 'ren'
        mapping['RENUSDC'] = 'republic-protocol'
      when 'rsr'
        mapping['RSRUSDC'] = 'reserve-rights-token'
      when 'oxt'
        mapping['OXTUSDC'] = 'orchid-protocol'
      when 'band'
        mapping['BANDUSDC'] = 'band-protocol'
      when 'nuls'
        mapping['NULSUSDC'] = 'nuls'
      when 'rvn'
        mapping['RVNUSDC'] = 'ravencoin'
      when 'stmx'
        mapping['STMXUSDC'] = 'storm'
      when 'ankr'
        mapping['ANKRUSDC'] = 'ankr'
      when 'ctxc'
        mapping['CTXCUSDC'] = 'cortex'
      when 'bts'
        mapping['BTSUSDC'] = 'bitshares'
      when 'ftm'
        mapping['FTMUSDC'] = 'fantom'
      when 'celo'
        mapping['CELOUSDC'] = 'celo'
      when 'cfx'
        mapping['CFXUSDC'] = 'conflux-token'
      when 'flow'
        mapping['FLOWUSDC'] = 'flow'
      when 'skl'
        mapping['SKLUSDC'] = 'skale'
      when 'storj'
        mapping['STORJUSDC'] = 'storj'
      when 'ogn'
        mapping['OGNUSDC'] = 'origin-protocol'
      when 'nkn'
        mapping['NKNUSDC'] = 'nkn'
      when 'dydx'
        mapping['DYDXUSDC'] = 'dydx'
      when 'imx'
        mapping['IMXUSDC'] = 'immutable-x'
      when 'gmx'
        mapping['GMXUSDC'] = 'gmx'
      when 'op'
        mapping['OPUSDC'] = 'optimism'
      when 'arb'
        mapping['ARBUSDC'] = 'arbitrum'
      when 'manta'
        mapping['MANTAUSDC'] = 'manta-network'
      when 'sei'
        mapping['SEIUSDC'] = 'sei-network'
      when 'sui'
        mapping['SUIUSDC'] = 'sui'
      when 'tia'
        mapping['TIAUSDC'] = 'celestia'
      when 'jup'
        mapping['JUPUSDC'] = 'jupiter'
      when 'bonk'
        mapping['BONKUSDC'] = 'bonk'
      when 'wif'
        mapping['WIFUSDC'] = 'dogwifhat'
      when 'pepe'
        mapping['PEPEUSDC'] = 'pepe'
      when 'floki'
        mapping['FLOKIUSDC'] = 'floki'
      when 'bome'
        mapping['BOMEUSDC'] = 'book-of-meme'
      when 'myro'
        mapping['MYROUSDC'] = 'myro'
      when 'popcat'
        mapping['POPCATUSDC'] = 'popcat'
      when 'book'
        mapping['BOOKUSDC'] = 'book-of-meme'
      when 'meme'
        mapping['MEMEUSDC'] = 'meme'
      when 'ordi'
        mapping['ORDIUSDC'] = 'ordinals'
      when 'rats'
        mapping['RATSUSDC'] = 'rats'
      when 'sats'
        mapping['SATSUSDC'] = 'sats'
      when '1000sats'
        mapping['1000SATSUSDC'] = '1000sats'
      when '1000floki'
        mapping['1000FLOKIUSDC'] = '1000floki'
      when '1000pepe'
        mapping['1000PEPEUSDC'] = '1000pepe'
      when '1000bonk'
        mapping['1000BONKUSDC'] = '1000bonk'
      when '1000shib'
        mapping['1000SHIBUSDC'] = '1000shib'
      when '1000lunc'
        mapping['1000LUNCUSDC'] = '1000lunc'
      when '1000xec'
        mapping['1000XECUSDC'] = '1000xec'
      when '1000btt'
        mapping['1000BTTUSDC'] = '1000btt'
      when '1000win'
        mapping['1000WINUSDC'] = '1000win'
      when '1000cake'
        mapping['1000CAKEUSDC'] = '1000cake'
      when '1000sxp'
        mapping['1000SXPUSDC'] = '1000sxp'
      when '1000comp'
        mapping['1000COMPUSDC'] = '1000comp'
      when '1000aave'
        mapping['1000AAVEUSDC'] = '1000aave'
      when '1000mkr'
        mapping['1000MKRUSDC'] = '1000mkr'
      when '1000yfi'
        mapping['1000YFIUSDC'] = '1000yfi'
      when '1000sushi'
        mapping['1000SUSHIUSDC'] = '1000sushi'
      when '1000inch'
        mapping['1000INCHUSDC'] = '1000inch'
      when '1000crv'
        mapping['1000CRVUSDC'] = '1000crv'
      when '1000snx'
        mapping['1000SNXUSDC'] = '1000snx'
      when '1000ren'
        mapping['1000RENUSDC'] = '1000ren'
      when '1000rsr'
        mapping['1000RSRUSDC'] = '1000rsr'
      when '1000oxt'
        mapping['1000OXTUSDC'] = '1000oxt'
      when '1000band'
        mapping['1000BANDUSDC'] = '1000band'
      when '1000nuls'
        mapping['1000NULSUSDC'] = '1000nuls'
      when '1000rvn'
        mapping['1000RVNUSDC'] = '1000rvn'
      when '1000stmx'
        mapping['1000STMXUSDC'] = '1000stmx'
      when '1000ankr'
        mapping['1000ANKRUSDC'] = '1000ankr'
      when '1000ctxc'
        mapping['1000CTXCUSDC'] = '1000ctxc'
      when '1000bts'
        mapping['1000BTSUSDC'] = '1000bts'
      when '1000ftm'
        mapping['1000FTMUSDC'] = '1000ftm'
      when '1000celo'
        mapping['1000CELOUSDC'] = '1000celo'
      when '1000cfx'
        mapping['1000CFXUSDC'] = 'conflux-token'
      when '1000flow'
        mapping['1000FLOWUSDC'] = 'flow'
      when '1000skl'
        mapping['1000SKLUSDC'] = 'skale'
      when '1000storj'
        mapping['1000STORJUSDC'] = 'storj'
      when '1000ogn'
        mapping['1000OGNUSDC'] = 'origin-protocol'
      when '1000nkn'
        mapping['1000NKNUSDC'] = 'nkn'
      when '1000dydx'
        mapping['1000DYDXUSDC'] = 'dydx'
      when '1000imx'
        mapping['1000IMXUSDC'] = 'immutable-x'
      when '1000gmx'
        mapping['1000GMXUSDC'] = 'gmx'
      when '1000op'
        mapping['1000OPUSDC'] = 'optimism'
      when '1000arb'
        mapping['1000ARBUSDC'] = 'arbitrum'
      when '1000manta'
        mapping['1000MANTAUSDC'] = 'manta-network'
      when '1000sei'
        mapping['1000SEIUSDC'] = 'sei-network'
      when '1000sui'
        mapping['1000SUIUSDC'] = 'sui'
      when '1000tia'
        mapping['1000TIAUSDC'] = 'celestia'
      when '1000jup'
        mapping['1000JUPUSDC'] = 'jupiter'
      when '1000bonk'
        mapping['1000BONKUSDC'] = '1000bonk'
      when '1000wif'
        mapping['1000WIFUSDC'] = 'dogwifhat'
      when '1000pepe'
        mapping['1000PEPEUSDC'] = 'pepe'
      when '1000floki'
        mapping['1000FLOKIUSDC'] = 'floki'
      when '1000bome'
        mapping['1000BOMEUSDC'] = 'book-of-meme'
      when '1000myro'
        mapping['1000MYROUSDC'] = 'myro'
      when '1000popcat'
        mapping['1000POPCATUSDC'] = 'popcat'
      when '1000book'
        mapping['1000BOOKUSDC'] = '1000book'
      when '1000meme'
        mapping['1000MEMEUSDC'] = 'meme'
      when '1000ordi'
        mapping['1000ORDIUSDC'] = '1000ordi'
      when '1000rats'
        mapping['1000RATSUSDC'] = '1000rats'
      when '1000sats'
        mapping['1000SATSUSDC'] = '1000sats'
      else
        # Fallback: Verwende den Base-Currency-Namen als CoinGecko-ID
        mapping[pair.gsub('/', '').upcase] = base_currency
      end
    end
    
    Rails.logger.info "📊 Symbol-Mapping erstellt: #{mapping.inspect}"
    mapping
  end
  
  def self.fetch_coin_data_from_coingecko(coin_ids)
    return {} if coin_ids.empty?
    
    # CoinGecko API: Top Coins nach Market Cap abrufen
    uri = URI("https://api.coingecko.com/api/v3/coins/markets")
    params = {
      'vs_currency' => 'usd',
      'ids' => coin_ids.join(','),
      'order' => 'market_cap_desc',
      'per_page' => 250,
      'page' => 1,
      'sparkline' => false,
      'price_change_percentage' => '24h'
    }
    
    uri.query = URI.encode_www_form(params)
    
    Rails.logger.info "📊 Rufe CoinGecko API auf: #{uri}"
    Rails.logger.info "📊 Coin IDs: #{coin_ids.inspect}"
    
    response = Net::HTTP.get_response(uri)
    
    Rails.logger.info "📊 CoinGecko Response Code: #{response.code}"
    
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "❌ Fehler beim Laden der CoinGecko Daten: #{response.code} - #{response.message}"
      Rails.logger.error "❌ Response Body: #{response.body}"
      return {}
    end
    
    coin_data = JSON.parse(response.body)
    Rails.logger.info "📊 CoinGecko Daten erhalten: #{coin_data.length} Coins"
    
    # Erstelle Hash mit CoinGecko-ID als Key
    coin_data.index_by { |coin| coin['id'] }
  rescue => e
    Rails.logger.error "❌ Fehler beim Laden der CoinGecko Daten: #{e.class} - #{e.message}"
    {}
  end
  
  def self.update_market_cap_in_database(coin_data, symbol_mapping)
    with_database_connection do
      symbol_mapping.each do |binance_symbol, coin_gecko_id|
        # Finde die Kryptowährung
        cryptocurrency = Cryptocurrency.find_by(symbol: binance_symbol)
        next unless cryptocurrency
        
        # Hole die CoinGecko-Daten
        coin_info = coin_data[coin_gecko_id]
        next unless coin_info
        
        # Extrahiere die korrekten Daten
        market_cap = coin_info['market_cap']
        market_cap_rank = coin_info['market_cap_rank']
        total_volume = coin_info['total_volume'] # 24h Handelsvolumen
        
        # Aktualisiere die Datenbank mit korrekten Market Cap Daten
        cryptocurrency.update!(
          market_cap: market_cap,
          market_cap_rank: market_cap_rank,
          volume_24h: total_volume,
          last_updated: Time.current
        )
        
        Rails.logger.info "📊 Market Cap für #{binance_symbol}: #{market_cap} (Rank: #{market_cap_rank}, Volume: #{total_volume})"
      end
    end
  rescue => e
    Rails.logger.error "❌ Fehler beim Aktualisieren der Market Cap Daten: #{e.class} - #{e.message}"
    end
  end

# --- WebSocket Message Handler ---
def handle_message(msg)
  begin
    # Sichere Typkonvertierung für msg.data
    data_string = nil
    
    # Prüfe verschiedene mögliche Nachrichtenformate
    if msg.respond_to?(:data)
      raw_data = msg.data
      if raw_data.is_a?(String)
        data_string = raw_data
      elsif raw_data.respond_to?(:to_s)
        data_string = raw_data.to_s
      elsif raw_data.respond_to?(:to_str)
        data_string = raw_data.to_str
      else
        Rails.logger.warn "⚠️ Unbekannter msg.data Typ: #{raw_data.class}"
        return
      end
    elsif msg.respond_to?(:to_s)
      # Fallback: Versuche msg direkt zu konvertieren
      data_string = msg.to_s
    else
      Rails.logger.warn "⚠️ msg hat keine data Eigenschaft und kann nicht konvertiert werden"
      return
    end
    
    # Ignoriere leere Nachrichten
    return if data_string.nil? || data_string.empty?
    
    # Ignoriere Ping/Pong Timeout Nachrichten und Invalid Requests
    if data_string.include?('Pong timeout') || data_string.include?('Ping timeout') || 
       data_string.include?('Invalid request') || data_string.include?('Invalid')
      Rails.logger.warn "⏰ Timeout/Invalid Nachricht ignoriert: #{data_string}"
      # Bei Timeout-Nachrichten sofort Reconnect erzwingen
      return
    end
    
    # Prüfe ob die Nachricht gültiges JSON ist
    begin
      data = JSON.parse(data_string)
    rescue JSON::ParserError => e
      debug_log "⏰ Ungültiges JSON ignoriert: #{data_string[0..100]}..."
      return
    end
    
    # Ping/Pong Handling - Binance sendet automatisch Pongs
    if data['pong'] || data_string.include?('pong')
      debug_log "🏓 Pong erhalten - Verbindung aktiv"
      return
    end
    
    # Ping-Nachrichten behandeln - Binance sendet manchmal Pings
    if data['ping'] || data_string.include?('ping')
      debug_log "🏓 Ping erhalten - Verbindung aktiv"
      return
    end
    
    # Kline Daten verarbeiten
    if data['e'] == 'kline'
      process_kline_data(data['s'], data['k'])
    end
    
  rescue TypeError => e
    # Behandle TypeError bei der Nachrichtenverarbeitung
    Rails.logger.error "❌ TypeError bei WebSocket Nachricht: #{e.message}"
    if msg.respond_to?(:data)
      debug_log "❌ msg.data Typ: #{msg.data.class}, Inhalt: #{msg.data.inspect}"
    else
      debug_log "❌ msg hat keine data Eigenschaft"
    end
  rescue => e
    Rails.logger.error "❌ Fehler beim Verarbeiten der WebSocket Nachricht: #{e.class} - #{e.message}"
  end
end

# Verarbeitet Kline-Daten (O, H, L, C, V)
private def process_kline_data(symbol, kline)
  debug_log "In process_kline_data für #{symbol}. Ist abgeschlossen: #{kline['x']}" # Debug-Log
  
  # 🚀 ECHTZEIT-UPDATE: Broadcaste JEDEN Preis sofort (auch unvollständige Kerzen)
  broadcast_price_realtime(symbol, kline['c'].to_f)
  
  # Speichere nur abgeschlossene Kerzen in die Datenbank für konsistente historische Daten
    if kline['x'] == true
      save_kline(symbol, kline)
    else
    debug_log "⏳ Überspringe Datenbank-Speicherung für unvollständige Kerze #{symbol} (Preis bereits gebroadcastet)"
    end
  rescue StandardError => e
    Rails.logger.error "Fehler beim Verarbeiten/Speichern der Kline für #{symbol}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
  end

  # Speichert die Kline-Daten in der Datenbank.
  private def save_kline(symbol, kline)
      verbose_log "💾 Speichere Kline für #{symbol}..."
    
    # Verwende die wiederverwendete Datenbankverbindung
  with_database_connection do
      # Typkonvertierung und Mapping
      cryptocurrency = Cryptocurrency.find_by(symbol: symbol)
      unless cryptocurrency
        Rails.logger.info "🆕 Erstelle neue Kryptowährung: #{symbol}"
        cryptocurrency = Cryptocurrency.create!(
          symbol: symbol,
          name: symbol, # Fallback, besser wäre Mapping
          current_price: kline['c'].to_f > 0 ? kline['c'].to_f : 1,
          market_cap: 1,
          market_cap_rank: 9999
        )
      end
      
      # Aktualisiere den aktuellen Preis der Kryptowährung
      cryptocurrency.update!(current_price: kline['c'].to_f)
    
    # Berechne und aktualisiere 24h Änderung
    update_24h_change(cryptocurrency, kline['c'].to_f)
    
    # Berechne RSI nur für abgeschlossene Kerzen
    if kline['x'] == true
      calculate_rsi_for_cryptocurrency(cryptocurrency)
    end
      
      attrs = {
        cryptocurrency: cryptocurrency,
        timestamp: Time.at(kline['t'] / 1000),
        open: kline['o'].to_f,
        high: kline['h'].to_f,
        low: kline['l'].to_f,
        close: kline['c'].to_f,
        volume: kline['v'].to_f,
      interval: '1m', # Immer 1m für Echtzeit-Updates
      }

      # Broadcast the price to the frontend
      broadcast_price(symbol, attrs[:close])

      begin
        result = CryptoHistoryData.record_data(attrs[:cryptocurrency], attrs, '1m')
        if result.persisted?
        verbose_log "📊 [#{attrs[:timestamp].strftime('%H:%M:%S')}] #{symbol} O:#{attrs[:open]} H:#{attrs[:high]} L:#{attrs[:low]} C:#{attrs[:close]} V:#{attrs[:volume]}"
        else
        debug_log "⏭️ Datensatz bereits vorhanden für #{symbol} um #{attrs[:timestamp].strftime('%H:%M:%S')}"
        end
      rescue => e
        Rails.logger.error "❌ Fehler beim Speichern in CryptoHistoryData: #{e.class} - #{e.message}"
    end
  end
rescue => e
  Rails.logger.error "❌ Fehler beim Speichern der Kline für #{symbol}: #{e.class} - #{e.message}"
end

# Berechne und aktualisiere die 24h Preisänderung
private def update_24h_change(cryptocurrency, current_price)
  begin
    # Hole den Preis von vor 24 Stunden
    twenty_four_hours_ago = Time.now - 24.hours
    
    # Suche nach dem letzten verfügbaren Datensatz von vor 24 Stunden (immer 1m für 24h-Berechnung)
    historical_data = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      timestamp: ..twenty_four_hours_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data
      # Vollständige 24h Daten verfügbar
      old_price = historical_data.close_price
      price_change = ((current_price - old_price) / old_price) * 100
      is_24h_complete = true
      
      Rails.logger.info "📈 24h Änderung für #{cryptocurrency.symbol}: #{price_change.round(2)}% (von #{old_price} auf #{current_price})"
    else
      # Keine 24h Daten verfügbar - verwende den ältesten verfügbaren Wert
      oldest_data = CryptoHistoryData.where(
        cryptocurrency: cryptocurrency,
        interval: '1m'
      ).order(:timestamp).first
      
      if oldest_data
        old_price = oldest_data.close_price
        time_diff_hours = (Time.now - oldest_data.timestamp) / 3600.0
        price_change = ((current_price - old_price) / old_price) * 100
        is_24h_complete = false
        
        Rails.logger.warn "⚠️ Keine 24h Daten für #{cryptocurrency.symbol}, verwende ältesten Wert (#{time_diff_hours.round(1)}h alt): #{price_change.round(2)}%"
      else
        # Keine historischen Daten überhaupt verfügbar
        Rails.logger.warn "⚠️ Keine historischen Daten für #{cryptocurrency.symbol} verfügbar"
        return
      end
    end
    
    # Aktualisiere die 24h Änderung in der Cryptocurrency-Tabelle
    cryptocurrency.update!(
      price_change_percentage_24h: price_change.round(2),
      price_change_24h_complete: is_24h_complete # Neues Feld für Frontend-Logik
    )
    
  rescue => e
    Rails.logger.error "❌ Fehler bei 24h-Berechnung für #{cryptocurrency.symbol}: #{e.class} - #{e.message}"
  end
end

# Professionelle Ping-Monitor-Funktionen nach Binance-Beispiel
private def start_ping_monitor(ws)
  # Send periodic ping frames to keep connection alive
  # Binance expects pong within 10 minutes, so we ping every 60 seconds
  Thread.new do
    last_pong_check = Time.now
    
    loop do
      sleep(60) # Ping every minute
      
      if ws && ws.respond_to?(:open?) && ws.open?
        ping_payload = Time.now.to_i.to_s
        Rails.logger.info "🏓 Sende PING mit Payload: #{ping_payload}"
        
        begin
          ws.ping(ping_payload)
        rescue => e
          Rails.logger.error "❌ Fehler beim Senden des Pings: #{e.message}"
          # Erzwinge Reconnect bei Ping-Fehler
          begin
            ws.close if ws.respond_to?(:close)
          rescue
            # Ignoriere Fehler beim Schließen
          end
          break
        end
      else
        Rails.logger.warn "⚠️ WebSocket nicht offen, stoppe Ping-Monitor"
        break
      end
    end
  end
rescue => e
  Rails.logger.error "❌ Fehler beim Starten des Ping-Monitors: #{e.class} - #{e.message}"
end

private def stop_ping_monitor(ping_interval_thread)
  if ping_interval_thread
    ping_interval_thread.kill
    ping_interval_thread = nil
    Rails.logger.info "📡 Ping-Monitor gestoppt"
  end
end

# Berechne RSI für eine Kryptowährung basierend auf Frontend-Einstellungen
private def calculate_rsi_for_cryptocurrency(cryptocurrency)
  begin
    # Lade aktuelle Frontend-Einstellungen
    timeframe = get_current_timeframe
    period = get_current_rsi_period
    
    # Verwende den RSI-Berechnungsservice mit Frontend-Parametern
    RsiCalculationService.calculate_rsi_for_cryptocurrency(cryptocurrency, timeframe, period)
  rescue => e
    Rails.logger.error "❌ Fehler bei RSI-Berechnung für #{cryptocurrency.symbol}: #{e.class} - #{e.message}"
  end
end

# Lade aktuellen Timeframe aus Frontend-Einstellungen
private def get_current_timeframe
  # Standard-Timeframe falls keine Einstellung gefunden wird
  default_timeframe = '1m'
  
  # Versuche Timeframe aus Rails-Cache zu lesen (wird vom Frontend gesetzt)
  cached_timeframe = Rails.cache.read('frontend_selected_timeframe')
  
  if cached_timeframe && ['1m', '5m', '15m', '1h', '4h', '1d'].include?(cached_timeframe)
    cached_timeframe
  else
    default_timeframe
  end
rescue => e
  Rails.logger.error "❌ Fehler beim Laden des Timeframes: #{e.message}"
  '1m' # Fallback
end

# Lade aktuelle RSI-Periode aus Frontend-Einstellungen
private def get_current_rsi_period
  # Standard-Periode falls keine Einstellung gefunden wird
  default_period = 14
  
  # Versuche Periode aus Rails-Cache zu lesen (wird vom Frontend gesetzt)
  cached_period = Rails.cache.read('frontend_selected_rsi_period')
  
  if cached_period && cached_period.to_i.between?(1, 50)
    cached_period.to_i
  else
    default_period
  end
rescue => e
  Rails.logger.error "❌ Fehler beim Laden der RSI-Periode: #{e.message}"
  14 # Fallback
end

# 🚀 ECHTZEIT-BROADCAST: Sendet jeden Preis sofort (optimiert für Performance)
def broadcast_price_realtime(symbol, price)
  # Minimale Logs für bessere Performance bei häufigen Updates
  debug_log "🚀 Echtzeit-Broadcast #{symbol}: #{price}"
  
  # Verwende eine separate, kurze Verbindung nur für den Lookup
  begin
    cryptocurrency = with_database_connection do
      # Konvertiere WebSocket-Symbol zu Datenbank-Format (btcusdc -> BTC/USDC)
      db_symbol = convert_websocket_symbol_to_db_format(symbol)
      
      # Versuche zuerst zu finden, erstelle falls nicht vorhanden
      Cryptocurrency.find_or_create_by(symbol: db_symbol) do |crypto|
        crypto.name = db_symbol
        crypto.current_price = price
        crypto.market_cap = 1
        crypto.market_cap_rank = 9999
      end
    end
    
    if cryptocurrency
      # Direkter ActionCable-Broadcast (da wir im gleichen Container sind)
      begin
        ActionCable.server.broadcast("prices", {
          cryptocurrency_id: cryptocurrency.id,
          price: price,
          symbol: symbol,
          timestamp: Time.now.iso8601,
          realtime: true # Flag für Echtzeit-Updates
        })
        
        debug_log "⚡ Echtzeit-Broadcast erfolgreich: #{symbol} (ID: #{cryptocurrency.id})"
      rescue => e
        Rails.logger.error "❌ Fehler beim Echtzeit-Broadcast: #{e.class} - #{e.message}"
      end
    else
      Rails.logger.warn "⚠️ Kryptowährung konnte nicht erstellt/gefunden werden für Symbol: #{symbol}"
    end
  rescue => e
    Rails.logger.error "❌ Fehler beim Echtzeit-Broadcast: #{e.class} - #{e.message}"
  end
end

# Konvertiert WebSocket-Symbol zu Datenbank-Format
def convert_websocket_symbol_to_db_format(websocket_symbol)
  # websocket_symbol kommt als "btcusdc", "ethusdc", etc.
  # Konvertiere zu "BTC/USDC", "ETH/USDC", etc.
  
  symbol_upper = websocket_symbol.upcase
  
  if symbol_upper.end_with?('USDC')
    base = symbol_upper.gsub('USDC', '')
    return "#{base}/USDC"
  elsif symbol_upper.end_with?('USDT')
    base = symbol_upper.gsub('USDT', '')
    return "#{base}/USDT"
  else
    # Fallback: return as-is
    return websocket_symbol
  end
end

# 📊 DATENBANK-BROADCAST: Sendet Preis bei abgeschlossenen Kerzen (mit vollständigen Logs)
def broadcast_price(symbol, price)  
  Rails.logger.info "🔔 Sende ActionCable Broadcast für abgeschlossene Kerze #{symbol}: #{price}"
  
  # Verwende eine separate, kurze Verbindung nur für den Lookup
  begin
    cryptocurrency = with_database_connection do
      # Konvertiere WebSocket-Symbol zu Datenbank-Format (btcusdc -> BTC/USDC)
      db_symbol = convert_websocket_symbol_to_db_format(symbol)
      
      # Versuche zuerst zu finden, erstelle falls nicht vorhanden
      Cryptocurrency.find_or_create_by(symbol: db_symbol) do |crypto|
        crypto.name = db_symbol
        crypto.current_price = price
        crypto.market_cap = 1
        crypto.market_cap_rank = 9999
      end
    end
    
    if cryptocurrency
      verbose_log "📡 Broadcasting an PricesChannel: #{cryptocurrency.id}, #{price}"
      
      # Direkter ActionCable-Broadcast (da wir im gleichen Container sind)
      begin
        ActionCable.server.broadcast("prices", {
          cryptocurrency_id: cryptocurrency.id,
          price: price,
          symbol: symbol,
          timestamp: Time.now.iso8601,
          candle_closed: true, # Flag für abgeschlossene Kerzen
          price_change_24h: cryptocurrency.price_change_percentage_24h,
          price_change_24h_formatted: cryptocurrency.price_change_percentage_24h_formatted,
          price_change_24h_complete: cryptocurrency.price_change_24h_complete?,
          market_cap: cryptocurrency.market_cap,
          market_cap_formatted: cryptocurrency.formatted_market_cap,
          volume_24h: cryptocurrency.volume_24h,
          volume_24h_formatted: cryptocurrency.formatted_volume_24h
        })
        
        Rails.logger.info "✅ ActionCable Broadcast erfolgreich gesendet"
      rescue => e
        Rails.logger.error "❌ Fehler beim ActionCable Broadcast: #{e.class} - #{e.message}"
        Rails.logger.error "❌ Backtrace: #{e.backtrace.first(3).join("\n")}"
      end
    else
      Rails.logger.warn "⚠️ Kryptowährung konnte nicht erstellt/gefunden werden für Symbol: #{symbol}"
    end
  rescue => e
    Rails.logger.error "❌ Fehler beim ActionCable Broadcast: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

# --- Modul-Funktion für Rails-Integration ---
# Diese Funktion kann von Rails aufgerufen werden, um den Service zu starten
def start_binance_websocket_service
  Rails.logger.info "🚀 Starte Binance WebSocket Service..."
  
  # DEBUG-AUSGABE zum Testen
  Rails.logger.info "🔧 DEBUG_MODE: #{DEBUG_MODE}"
  Rails.logger.info "🔧 VERBOSE_LOGGING: #{VERBOSE_LOGGING}"
  Rails.logger.info "🔧 Rails.logger verfügbar: #{!Rails.logger.nil?}"
  
  # Starte Market Cap Updates in separatem Thread
  Thread.new do
    Rails.logger.info "📊 Starte Market Cap Update Timer..."
    
    loop do
      begin
        MarketCapService.fetch_market_cap_data
        sleep MARKET_CAP_UPDATE_INTERVAL
      rescue => e
        Rails.logger.error "❌ Fehler im Market Cap Update Timer: #{e.class} - #{e.message}"
        sleep 60 # Warte 1 Minute bei Fehler
      end
    end
  end
  
  # Haupt-WebSocket Loop mit verbesserter Reconnect-Logik
  reconnect_attempts = 0
  last_successful_connection = Time.now
  
  loop do
    begin
      Rails.logger.info "🔄 Starte WebSocket Verbindung (Versuch #{reconnect_attempts + 1})..."
      
      # Lade Paare aus der Konfiguration
      pairs = PairSelector.load_pairs
      
      if pairs.empty?
        Rails.logger.error "❌ Keine Paare gefunden. Beende Service."
        break
      end
      
      # Erstelle WebSocket URL für alle Paare mit 1m Timeframe (für Echtzeit-Updates)
      stream_names = pairs.map { |pair| "#{pair}@kline_1m" }
      ws_url = "#{BINANCE_WS_BASE_URL}/#{stream_names.join('/')}"
      
      Rails.logger.info "🔗 Verbinde mit: #{ws_url}"
      
      # Erstelle WebSocket Verbindung mit verbesserter Fehlerbehandlung
      begin
        ws = WebSocket::Client::Simple.connect ws_url
        
        # Variablen für Ping/Pong-Tracking (nach Binance-Beispiel)
        last_pong_received = Time.now
        ping_interval_thread = nil
        
        # Event Handler
        ws.on :message do |msg|
          handle_message(msg)
        end
        
        ws.on :open do
          Rails.logger.info "✅ WebSocket Verbindung geöffnet"
          last_successful_connection = Time.now
          reconnect_attempts = 0 # Reset Reconnect-Zähler bei erfolgreicher Verbindung
          last_pong_received = Time.now
          ping_interval_thread = start_ping_monitor(ws)
        end
        
        ws.on :error do |e|
          Rails.logger.error "❌ WebSocket Fehler: #{e.message}"
        end
        
        ws.on :close do |e|
          Rails.logger.warn "⚠️ WebSocket Verbindung geschlossen: #{e.code} - #{e.reason}"
          stop_ping_monitor(ping_interval_thread)
        end
        
        # Handle ping frames from server (nach Binance-Beispiel)
        ws.on :ping do |event|
          debug_log "🏓 PING von Server erhalten, Payload: #{event.data}"
          # WebSocket client sendet automatisch PONG response
          # Aber wir können es auch manuell senden:
          ws.pong(event.data)
          debug_log "🏓 PONG-Antwort gesendet mit Payload: #{event.data}"
        end
        
        # Handle pong frames from server (nach Binance-Beispiel)
        ws.on :pong do |event|
          debug_log "🏓 PONG von Server erhalten, Payload: #{event.data}"
          last_pong_received = Time.now
        end
        
        # Proaktive Ping/Pong-Behandlung für stabile Verbindung
        Rails.logger.info "📡 Binance WebSocket Stream aktiv - proaktive Ping/Pong Behandlung"
        
        # Professionelle WebSocket-Behandlung nach Binance-Beispiel
        begin
          if ws.respond_to?(:loop)
            ws.loop
          elsif ws.respond_to?(:run)
            ws.run
          elsif ws.respond_to?(:run)
            ws.run
          else
            # Fallback: Warte auf Verbindungsende mit kürzeren Checks
            loop do
              sleep 1
              break unless ws.respond_to?(:open?) && ws.open?
            end
          end
        rescue => e
          Rails.logger.error "❌ WebSocket.run Fehler: #{e.class} - #{e.message}"
        end
        
      rescue => e
        Rails.logger.error "❌ WebSocket Verbindungsfehler: #{e.class} - #{e.message}"
      end
      
    rescue => e
      reconnect_attempts += 1
      Rails.logger.error "❌ WebSocket Service Fehler (Versuch #{reconnect_attempts}): #{e.class} - #{e.message}"
      
      # Exponentieller Backoff mit Maximum
      delay = [RECONNECT_INITIAL_DELAY_SECONDS * (2 ** (reconnect_attempts - 1)), RECONNECT_MAX_DELAY_SECONDS].min
      
      if reconnect_attempts >= MAX_RECONNECT_ATTEMPTS
        Rails.logger.error "❌ Maximale Reconnect-Versuche erreicht. Pausiere für 5 Minuten..."
        sleep 300 # 5 Minuten Pause
        reconnect_attempts = 0 # Reset für nächsten Zyklus
      else
        Rails.logger.info "⏳ Warte #{delay} Sekunden vor Reconnect (Versuch #{reconnect_attempts + 1})..."
        sleep delay
      end
    end
  end
end