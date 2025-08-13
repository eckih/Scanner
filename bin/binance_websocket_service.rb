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
if defined?(Rails.logger) && !defined?(Rails::Console)
  Rails.logger.info "🔧 WebSocket Service Datei wird geladen..."
  Rails.logger.info "🔧 ENV DEBUG_MODE: #{ENV.fetch('DEBUG_MODE', 'not_set')}"
  Rails.logger.info "🔧 ENV VERBOSE_LOGGING: #{ENV.fetch('VERBOSE_LOGGING', 'not_set')}"
end

# --- Debug-Konfiguration ---
# Setze auf false, um detaillierte Logs zu deaktivieren (bessere Performance)
DEBUG_MODE = ENV.fetch('DEBUG_MODE', 'false').downcase == 'true'
VERBOSE_LOGGING = ENV.fetch('VERBOSE_LOGGING', 'false').downcase == 'true'

# Hilfsfunktion für bedingte Logs
def debug_log(message)
  return if ENV['RAILS_CONSOLE'] == 'true'
  Rails.logger.debug(message) if DEBUG_MODE && Rails.logger
end

def verbose_log(message)
  return if ENV['RAILS_CONSOLE'] == 'true'
  Rails.logger.info(message) if VERBOSE_LOGGING && Rails.logger
end

def console_safe_log(message, level = :info)
  return if ENV['RAILS_CONSOLE'] == 'true' || defined?(Rails::Console)
  Rails.logger.send(level, message) if Rails.logger
end

# Globale Funktion um alle Rails.logger Aufrufe zu ersetzen
def safe_rails_log(message, level = :info)
  return if ENV['RAILS_CONSOLE'] == 'true' || defined?(Rails::Console)
  Rails.logger.send(level, message) if Rails.logger
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

# --- Candlestick Update Intervall ---
CANDLESTICK_UPDATE_INTERVAL = 60 # 1 Minute: Wie oft Kerzendaten aktualisiert werden

# --- Connection Pool Management ---
# Optimiertes Connection Pool Management für PostgreSQL (Multi-Threading fähig)
def with_database_connection
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    begin
      yield
    rescue ActiveRecord::ConnectionTimeoutError => e
      Rails.logger.error "[X] Connection Pool Timeout: #{e.message}"
      # PostgreSQL kann mehr Verbindungen handhaben, also weniger aggressive Retry-Logik
      sleep 0.05
      retry
    rescue PG::ConnectionBad, PG::UnableToSend => e
      Rails.logger.error "[X] PostgreSQL Verbindungsfehler: #{e.message}"
      # Versuche Verbindung wiederherzustellen
      connection.reconnect! if connection.respond_to?(:reconnect!)
      retry
    rescue => e
      Rails.logger.error "[X] Datenbankfehler: #{e.class} - #{e.message}"
      raise e
    end
  end
end

# --- Logger-Konfiguration ---
# Verwende Rails.logger statt eigener Logger-Konstante

# --- WebSocket Zähler ---
# Globale Zähler für empfangene Daten
$websocket_message_counter = 0
$websocket_kline_counter = 0
$websocket_price_update_counter = 0
$websocket_rsi_calculation_counter = 0

# Datenrate-Tracking (Nachrichten pro Minute)
$message_timestamps = []
$last_data_rate = 0

# Hilfsfunktion für Zähler-Updates
def increment_websocket_counter(counter_type)
  case counter_type
  when :message
    $websocket_message_counter += 1
    # Füge Zeitstempel für Datenrate-Berechnung hinzu
    current_time = Time.now
    $message_timestamps << current_time
    
    # Behalte nur Nachrichten der letzten 60 Sekunden für Datenrate-Berechnung
    cutoff_time = current_time - 60
    $message_timestamps.reject! { |timestamp| timestamp < cutoff_time }
    
    # Berechne aktuelle Datenrate (Nachrichten pro Minute)
    $last_data_rate = ($message_timestamps.length * 60.0 / 60.0).round(1)
  when :kline
    $websocket_kline_counter += 1
  when :price_update
    $websocket_price_update_counter += 1
  when :rsi_calculation
    $websocket_rsi_calculation_counter += 1
  end
end

def log_websocket_counters
  console_safe_log "[Grafik] WebSocket Zähler - Nachrichten: #{$websocket_message_counter}, Klines: #{$websocket_kline_counter}, Preis-Updates: #{$websocket_price_update_counter}, RSI-Berechnungen: #{$websocket_rsi_calculation_counter}, Datenrate: #{$last_data_rate}/min"
  
  # Broadcast Zähler per ActionCable
  broadcast_websocket_counters
end

def broadcast_websocket_counters
  begin
    ActionCable.server.broadcast("prices", {
      update_type: 'counters',
      message_counter: $websocket_message_counter,
      kline_counter: $websocket_kline_counter,
      price_update_counter: $websocket_price_update_counter,
      rsi_calculation_counter: $websocket_rsi_calculation_counter,
      data_rate: $last_data_rate,
      timestamp: Time.now.iso8601
    })
    console_safe_log "📡 Zähler gebroadcastet: Nachrichten=#{$websocket_message_counter}, Klines=#{$websocket_kline_counter}, Preis-Updates=#{$websocket_price_update_counter}, RSI-Berechnungen=#{$websocket_rsi_calculation_counter}, Datenrate=#{$last_data_rate}/min"
  rescue => e
    console_safe_log "[X] Fehler beim Broadcast der Zähler: #{e.message}"
  end
end

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

    console_safe_log "Lade Paare direkt aus bot.json (ohne Binance API)..."

    if whitelist.empty?
      Rails.logger.warn "Keine Whitelist konfiguriert. Service wird beendet."
      return []
    end

    # Konvertiere bot.json Format (BTC/USDC) zu Binance WebSocket Format (btcusdc)
    selected_pairs = whitelist.map { |pair| pair.gsub('/', '').downcase }
    
    # Entferne Blacklist-Paare falls vorhanden
    if blacklist.any?
      blacklist_symbols = blacklist.map { |p| p.gsub('/', '').downcase }.to_set
      selected_pairs = selected_pairs.reject { |pair| blacklist_symbols.include?(pair) }
      verbose_log "Blacklist angewendet: #{blacklist.inspect}"
    end
    console_safe_log "Ausgewählte Paare für den Stream: #{selected_pairs.join(', ')} (#{selected_pairs.length} Paare)"
    selected_pairs
  end
end

# --- Market Cap Service ---
# Diese Klasse ist für das Laden von Market Cap Daten von der CoinGecko API zuständig.
class MarketCapService
  def self.fetch_market_cap_data
    console_safe_log "[Grafik] Lade Market Cap Daten von CoinGecko API..."
    
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
        Rails.logger.warn "[!] Keine CoinGecko Daten erhalten"
        return
      end
      
      console_safe_log "[Grafik] Verarbeite #{coin_data.length} Coins für Market Cap Update"
      
      # Aktualisiere die Datenbank
      update_market_cap_in_database(coin_data, symbol_mapping)
      
      console_safe_log "[OK] Market Cap Daten erfolgreich aktualisiert"
      
    rescue => e
      Rails.logger.error "[X] Fehler beim Laden der Market Cap Daten: #{e.class} - #{e.message}"
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
    
    Rails.logger.info "[Grafik] Symbol-Mapping erstellt: #{mapping.inspect}"
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
    
    Rails.logger.info "[Grafik] Rufe CoinGecko API auf: #{uri}"
    Rails.logger.info "[Grafik] Coin IDs: #{coin_ids.inspect}"
    
    response = Net::HTTP.get_response(uri)
    
    Rails.logger.info "[Grafik] CoinGecko Response Code: #{response.code}"
    
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[X] Fehler beim Laden der CoinGecko Daten: #{response.code} - #{response.message}"
      Rails.logger.error "[X] Response Body: #{response.body}"
      return {}
    end
    
    coin_data = JSON.parse(response.body)
    Rails.logger.info "[Grafik] CoinGecko Daten erhalten: #{coin_data.length} Coins"
    
    # Erstelle Hash mit CoinGecko-ID als Key
    coin_data.index_by { |coin| coin['id'] }
  rescue => e
    Rails.logger.error "[X] Fehler beim Laden der CoinGecko Daten: #{e.class} - #{e.message}"
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
        
        Rails.logger.info "[Grafik] Market Cap für #{binance_symbol}: #{market_cap} (Rank: #{market_cap_rank}, Volume: #{total_volume})"
      end
    end
  rescue => e
    Rails.logger.error "[X] Fehler beim Aktualisieren der Market Cap Daten: #{e.class} - #{e.message}"
    end
  end

# --- WebSocket Message Handler ---
def handle_message(msg)
  begin
    # Zähler für empfangene Nachrichten erhöhen
    increment_websocket_counter(:message)
    
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
        console_safe_log "[!] Unbekannter msg.data Typ: #{raw_data.class}"
        return
      end
    elsif msg.respond_to?(:to_s)
      # Fallback: Versuche msg direkt zu konvertieren
      data_string = msg.to_s
    else
      console_safe_log "[!] msg hat keine data Eigenschaft und kann nicht konvertiert werden"
      return
    end
    
    # Ignoriere leere Nachrichten
    return if data_string.nil? || data_string.empty?
    
    # Ignoriere Ping/Pong Timeout Nachrichten und Invalid Requests
    if data_string.include?('Pong timeout') || data_string.include?('Ping timeout') || 
       data_string.include?('Invalid request') || data_string.include?('Invalid')
      console_safe_log "⏰ Timeout/Invalid Nachricht ignoriert: #{data_string}"
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
    console_safe_log "[X] TypeError bei WebSocket Nachricht: #{e.message}"
    if msg.respond_to?(:data)
      debug_log "[X] msg.data Typ: #{msg.data.class}, Inhalt: #{msg.data.inspect}"
    else
      debug_log "[X] msg hat keine data Eigenschaft"
    end
    # Ignoriere TypeError und fahre fort
    return
  rescue => e
    console_safe_log "[X] Fehler beim Verarbeiten der WebSocket Nachricht: #{e.class} - #{e.message}"
    # Ignoriere andere Fehler und fahre fort
    return
  end
end

# Verarbeitet Kline-Daten (O, H, L, C, V)
private def process_kline_data(symbol, kline)
  debug_log "In process_kline_data für #{symbol}. Ist abgeschlossen: #{kline['x']}" # Debug-Log
  
  # Zähler für Kline-Daten erhöhen
  increment_websocket_counter(:kline)
  
  # 🚀 ECHTZEIT-UPDATE: Broadcaste JEDEN Preis sofort (auch unvollständige Kerzen)
  broadcast_price_realtime(symbol, kline['c'].to_f)
  
  # Zähler für Preis-Updates erhöhen
  increment_websocket_counter(:price_update)
  
  # Indikator-Berechnungen für alle Kerzen (auch unvollständige)
  begin
    # Finde Kryptowährung - ERSTELLE FEHLENDE AUS BOT.JSON
    db_symbol = convert_websocket_symbol_to_db_format(symbol)
    cryptocurrency = Cryptocurrency.find_by(symbol: db_symbol)
    
    # Erstelle fehlende Cryptocurrency, wenn sie in der Whitelist ist
    if cryptocurrency.nil?
      begin
        # Prüfe, ob das Symbol in der bot.json Whitelist ist
        config_path = File.join(__dir__, '../config/bot.json')
        if File.exist?(config_path)
          config = JSON.parse(File.read(config_path))
          whitelist = config.dig('exchange', 'pair_whitelist') || []
          
          if whitelist.include?(db_symbol)
            coin_name = db_symbol.split('/').first
            cryptocurrency = Cryptocurrency.create!(
              symbol: db_symbol,
              name: coin_name,
              current_price: kline['c'].to_f,
              market_cap: 1_000_000,  # Dummy-Wert
              market_cap_rank: 999    # Dummy-Wert
            )
            console_safe_log "[OK] Neues Pair #{db_symbol} automatisch erstellt (ID: #{cryptocurrency.id})"
          else
            console_safe_log "[!] Symbol #{db_symbol} nicht in Whitelist - überspringe"
          end
        end
      rescue => e
        console_safe_log "[X] Fehler beim Erstellen von #{db_symbol}: #{e.message}"
      end
    end
    
    if cryptocurrency
      # Aktualisiere Preis
      cryptocurrency.update!(current_price: kline['c'].to_f)
      
      current_timeframe = get_current_timeframe
      period = get_current_rsi_period
      
      # RSI-Berechnung nur bei geschlossenen Kerzen (Performance-Optimierung)
      if kline['x'] # Nur bei abgeschlossenen Kerzen
        rsi_value = IndicatorCalculationService.calculate_and_save_rsi(cryptocurrency, '1m', period)
        increment_websocket_counter(:rsi_calculation)
        debug_log "[Grafik] RSI berechnet für #{cryptocurrency.symbol}: #{rsi_value} (geschlossene Kerze)"
      end
      
      # ROC und ROC' alle 30 Sekunden (auch für unvollständige Kerzen)
      @last_roc_calculation ||= {}
      current_time = Time.now
      last_roc_time = @last_roc_calculation[cryptocurrency.id] || (current_time - 31)
      
      if current_time - last_roc_time >= 30 # Alle 30 Sekunden
        begin
          # ROC-Berechnung mit aktuellem Close-Kurs
          roc_value = IndicatorCalculationService.calculate_and_save_roc(cryptocurrency, '1m', 14)
          debug_log "[Grafik] ROC berechnet für #{cryptocurrency.symbol}: #{roc_value}% (alle 30s)"
          
          # ROC Derivative-Berechnung mit aktuellem Close-Kurs
          roc_derivative_value = IndicatorCalculationService.calculate_and_save_roc_derivative(cryptocurrency, '1m', 14)
          debug_log "[Grafik] ROC' berechnet für #{cryptocurrency.symbol}: #{roc_derivative_value}% (alle 30s)"
          
          @last_roc_calculation[cryptocurrency.id] = current_time
        rescue => e
          debug_log "[!] ROC/ROC' Berechnung für #{cryptocurrency.symbol} fehlgeschlagen: #{e.message}"
        end
      end
      
    else
      # Warnung nur beim ersten Mal pro Symbol
      @warned_indicator_symbols ||= Set.new
      unless @warned_indicator_symbols.include?(symbol)
        console_safe_log "[!] Cryptocurrency #{db_symbol} nicht in Whitelist - überspringe Indikator-Berechnungen"
        @warned_indicator_symbols.add(symbol)
      end
    end
  rescue => e
    console_safe_log "[X] FEHLER bei Indikator-Berechnungen für #{symbol}: #{e.message}"
  end
  
  # Speichere nur abgeschlossene Kerzen in die Datenbank für konsistente historische Daten
    if kline['x'] == true
      save_kline(symbol, kline)
    else
      debug_log "⏳ Überspringe Datenbank-Speicherung für unvollständige Kerze #{symbol} (Preis bereits gebroadcastet)"
    end
  rescue StandardError => e
    safe_rails_log "Fehler beim Verarbeiten/Speichern der Kline für #{symbol}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}", :error
  end

  # Speichert die Kline-Daten in der Datenbank.
  private def save_kline(symbol, kline)
      verbose_log "💾 Speichere Kline für #{symbol}..."
    
    # Verwende die wiederverwendete Datenbankverbindung
  with_database_connection do
      # Konvertiere WebSocket-Symbol zu Datenbank-Format
      db_symbol = convert_websocket_symbol_to_db_format(symbol)
      
      # Suche nur nach bestehenden Cryptocurrencies - KEINE NEUE ERSTELLUNG
      cryptocurrency = Cryptocurrency.find_by(symbol: db_symbol)
      unless cryptocurrency
        console_safe_log "[!] Cryptocurrency #{db_symbol} nicht in Whitelist - überspringe Kline-Speicherung"
        return
      end
      
      # Aktualisiere den aktuellen Preis der Kryptowährung
      cryptocurrency.update!(current_price: kline['c'].to_f)
    
    # Berechne und aktualisiere 24h Änderung (nur alle 5 Minuten um API-Limits zu schonen)
    if should_update_24h_change?(cryptocurrency)
      update_24h_change(cryptocurrency, kline['c'].to_f)
    end
    
    # RSI wird bereits in process_kline_data berechnet - keine doppelte Berechnung nötig
    debug_log "[Grafik] RSI bereits berechnet in process_kline_data für #{cryptocurrency.symbol}"
      
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
          verbose_log "[Grafik] [#{attrs[:timestamp].strftime('%H:%M:%S')}] #{symbol} O:#{attrs[:open]} H:#{attrs[:high]} L:#{attrs[:low]} C:#{attrs[:close]} V:#{attrs[:volume]}"
          
          # Broadcast candle data update for mini-candlesticks
          broadcast_candle_update(cryptocurrency, attrs)
        else
          debug_log "⏭️ Datensatz bereits vorhanden für #{symbol} um #{attrs[:timestamp].strftime('%H:%M:%S')}"
        end
      rescue => e
        safe_rails_log "[X] Fehler beim Speichern in CryptoHistoryData: #{e.class} - #{e.message}", :error
    end
  end
  rescue => e
    safe_rails_log "[X] Fehler beim Speichern der Kline für #{symbol}: #{e.class} - #{e.message}", :error
  end

# Berechne und aktualisiere die 24h, 1h und 30min Preisänderungen
private def update_24h_change(cryptocurrency, current_price)
  # Änderungen werden jetzt dynamisch im Model berechnet
  # Nur last_updated aktualisieren
  cryptocurrency.update!(last_updated: Time.now)
end

# Prüfe ob 24h Änderung aktualisiert werden soll (alle 5 Minuten)
private def should_update_24h_change?(cryptocurrency)
  # Wenn last_updated nil ist oder älter als 5 Minuten, dann aktualisieren
  return true if cryptocurrency.last_updated.nil?
  
  time_since_last_update = Time.now - cryptocurrency.last_updated
  time_since_last_update >= 5.minutes
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
          Rails.logger.error "[X] Fehler beim Senden des Pings: #{e.message}"
          # Erzwinge Reconnect bei Ping-Fehler
          begin
            ws.close if ws.respond_to?(:close)
          rescue
            # Ignoriere Fehler beim Schließen
          end
          break
        end
      else
        Rails.logger.warn "[!] WebSocket nicht offen, stoppe Ping-Monitor"
        break
      end
    end
  end
rescue => e
  Rails.logger.error "[X] Fehler beim Starten des Ping-Monitors: #{e.class} - #{e.message}"
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
    
    # Verwende den neuen IndicatorCalculationService
    IndicatorCalculationService.calculate_and_save_rsi(cryptocurrency, timeframe, period)
  rescue => e
    console_safe_log "[X] Fehler bei RSI-Berechnung für #{cryptocurrency.symbol}: #{e.class} - #{e.message}"
  end
end



  
  # Lade aktuellen Timeframe aus Frontend-Einstellungen
  private def get_current_timeframe
    # Standard-Timeframe falls keine Einstellung gefunden wird
    default_timeframe = '1m'  # Geändert zurück zu '1m' da wir 1m-Daten haben
    
    # Versuche Timeframe aus Rails-Cache zu lesen (wird vom Frontend gesetzt)
    cached_timeframe = Rails.cache.read('frontend_selected_timeframe')
    
    if cached_timeframe && ['1m', '5m', '15m', '1h', '4h', '1d'].include?(cached_timeframe)
      cached_timeframe
    else
      default_timeframe
    end
  rescue => e
    Rails.logger.error "[X] Fehler beim Laden des Timeframes: #{e.message}"
    '1m' # Fallback - geändert zurück zu '1m'
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
  Rails.logger.error "[X] Fehler beim Laden der RSI-Periode: #{e.message}"
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
      
      # Suche nur nach bestehenden Cryptocurrencies - KEINE NEUE ERSTELLUNG
      Cryptocurrency.find_by(symbol: db_symbol)
    end
    
    if cryptocurrency
      # Direkter ActionCable-Broadcast (da wir im gleichen Container sind)
      begin
        # Berechne 24h, 1h und 30min Änderungen
        price_changes = calculate_price_changes(cryptocurrency, price)
        
        ActionCable.server.broadcast("prices", {
          cryptocurrency_id: cryptocurrency.id,
          price: price,
          symbol: symbol,
          timestamp: Time.now.iso8601,
          realtime: true,
          price_changes: price_changes
        })
        debug_log "🚀 Preis-Broadcast für #{symbol}: #{price} (24h: #{price_changes[:change_24h]}%, 1h: #{price_changes[:change_1h]}%, 30min: #{price_changes[:change_30min]}%)"
      rescue => e
        console_safe_log "[X] FEHLER beim Preis-Broadcast für #{symbol}: #{e.message}"
      end
    else
      # Warnung nur beim ersten Mal pro Symbol
      @warned_symbols ||= Set.new
      unless @warned_symbols.include?(symbol)
        console_safe_log "[!] Symbol #{symbol} (#{convert_websocket_symbol_to_db_format(symbol)}) nicht in Whitelist - überspringe Preis-Update"
        @warned_symbols.add(symbol)
      end
    end
  rescue => e
    Rails.logger.error "[X] Fehler beim Echtzeit-Broadcast: #{e.class} - #{e.message}"
  end
end

# Berechnet 24h, 1h und 30min Preisänderungen für ActionCable-Broadcast
def calculate_price_changes(cryptocurrency, current_price)
  begin
    changes = {
      change_24h: 0.0,
      change_1h: 0.0,
      change_30min: 0.0,
      has_24h_data: false,
      has_1h_data: false,
      has_30min_data: false
    }
    
    # 24h Änderung
    twenty_four_hours_ago = Time.now - 24.hours
    historical_data_24h = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      timestamp: ..twenty_four_hours_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data_24h
      old_price_24h = historical_data_24h.close_price
      changes[:change_24h] = ((current_price - old_price_24h) / old_price_24h) * 100
      changes[:has_24h_data] = true
    end
    
    # 1h Änderung
    one_hour_ago = Time.now - 1.hour
    historical_data_1h = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      timestamp: ..one_hour_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data_1h
      old_price_1h = historical_data_1h.close_price
      changes[:change_1h] = ((current_price - old_price_1h) / old_price_1h) * 100
      changes[:has_1h_data] = true
    end
    
    # 30min Änderung
    thirty_minutes_ago = Time.now - 30.minutes
    historical_data_30min = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      timestamp: ..thirty_minutes_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data_30min
      old_price_30min = historical_data_30min.close_price
      changes[:change_30min] = ((current_price - old_price_30min) / old_price_30min) * 100
      changes[:has_30min_data] = true
    end
    
    # Runde alle Werte auf 2 Dezimalstellen
    changes[:change_24h] = changes[:change_24h].round(2)
    changes[:change_1h] = changes[:change_1h].round(2)
    changes[:change_30min] = changes[:change_30min].round(2)
    
    changes
  rescue => e
    Rails.logger.error "[X] Fehler bei Preisänderungs-Berechnung für #{cryptocurrency.symbol}: #{e.class} - #{e.message}"
    {
      change_24h: 0.0,
      change_1h: 0.0,
      change_30min: 0.0,
      has_24h_data: false,
      has_1h_data: false,
      has_30min_data: false
    }
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

# [Grafik] DATENBANK-BROADCAST: Sendet Preis bei abgeschlossenen Kerzen (mit vollständigen Logs)
def broadcast_price(symbol, price)  
  Rails.logger.info "🔔 Sende ActionCable Broadcast für abgeschlossene Kerze #{symbol}: #{price}"
  
  # Verwende eine separate, kurze Verbindung nur für den Lookup
  begin
    cryptocurrency = with_database_connection do
      # Konvertiere WebSocket-Symbol zu Datenbank-Format (btcusdc -> BTC/USDC)
      db_symbol = convert_websocket_symbol_to_db_format(symbol)
      
      # Suche nur nach bestehenden Cryptocurrencies - KEINE NEUE ERSTELLUNG
      Cryptocurrency.find_by(symbol: db_symbol)
    end
    
    if cryptocurrency
      verbose_log "📡 Broadcasting an PricesChannel: #{cryptocurrency.id}, #{price}"
      
      # Direkter ActionCable-Broadcast (da wir im gleichen Container sind)
      begin
        # Berechne 24h, 1h und 30min Änderungen
        price_changes = calculate_price_changes(cryptocurrency, price)
        
        ActionCable.server.broadcast("prices", {
          cryptocurrency_id: cryptocurrency.id,
          price: price,
          symbol: symbol,
          timestamp: Time.now.iso8601,
          candle_closed: true, # Flag für abgeschlossene Kerzen
          price_changes: price_changes
        })
        
        verbose_log "[OK] Broadcast erfolgreich: #{symbol} (ID: #{cryptocurrency.id}) mit Änderungen: 24h=#{price_changes[:change_24h]}%, 1h=#{price_changes[:change_1h]}%, 30min=#{price_changes[:change_30min]}%"
      rescue => e
        Rails.logger.error "[X] Fehler beim Broadcast: #{e.class} - #{e.message}"
      end
    else
      # Warnung nur beim ersten Mal pro Symbol für broadcast_price
      @warned_symbols_broadcast ||= Set.new
      unless @warned_symbols_broadcast.include?(symbol)
        console_safe_log "[!] Symbol #{symbol} (#{convert_websocket_symbol_to_db_format(symbol)}) nicht in Whitelist - überspringe abgeschlossene Kerze"
        @warned_symbols_broadcast.add(symbol)
      end
    end
  rescue => e
    Rails.logger.error "[X] Fehler beim ActionCable Broadcast: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

# [Kerze] CANDLE BROADCAST: Sendet Candle-Daten für Mini-Candlesticks
def broadcast_candle_update(cryptocurrency, candle_data)
  Rails.logger.info "[Kerze] Sende Candle-Update für #{cryptocurrency.symbol}: O:#{candle_data[:open]} H:#{candle_data[:high]} L:#{candle_data[:low]} C:#{candle_data[:close]}"
  
  begin
    # Hole die letzten 5 Kerzen für den Mini-Candlestick
    candles = CryptoHistoryData.where(cryptocurrency: cryptocurrency, interval: '1m')
                              .order(timestamp: :desc)
                              .limit(5)
                              .reverse
    
    candle_array = candles.map do |candle|
      {
        open: candle.open_price,
        high: candle.high_price,
        low: candle.low_price,
        close: candle.close_price,
        timestamp: candle.timestamp,
        isGreen: candle.close_price > candle.open_price
      }
    end
    
    verbose_log "[Grafik] Broadcasting Candle-Update für #{cryptocurrency.symbol}: #{candle_array.length} Kerzen"
    
    # ActionCable-Broadcast für Candle-Updates
    ActionCable.server.broadcast("prices", {
      cryptocurrency_id: cryptocurrency.id,
      symbol: cryptocurrency.symbol,
      type: 'candle_update',
      candles: candle_array,
      timestamp: Time.now.iso8601
    })
    
    verbose_log "[OK] Candle-Broadcast erfolgreich: #{cryptocurrency.symbol}"
  rescue => e
    Rails.logger.error "[X] Fehler beim Candle-Broadcast: #{e.class} - #{e.message}"
  end
end

# [Kerze] MINÜTLICHES CANDLESTICK UPDATE: Sendet alle Kerzendaten jede Minute
def broadcast_all_candlesticks_update
  Rails.logger.info "[Kerze] Starte minütliches Candlestick-Update für alle Kryptowährungen..."
  
  begin
    # Lade alle aktiven Kryptowährungen
    cryptocurrencies = with_database_connection do
      Cryptocurrency.all
    end
    
    if cryptocurrencies.empty?
      Rails.logger.warn "[!] Keine Kryptowährungen für Candlestick-Update gefunden"
      return
    end
    
    Rails.logger.info "[Grafik] Aktualisiere Candlesticks für #{cryptocurrencies.length} Kryptowährungen..."
    
    cryptocurrencies.each do |cryptocurrency|
      begin
        # Hole die letzten 5 Kerzen für diese Kryptowährung
        candles = with_database_connection do
          CryptoHistoryData.where(cryptocurrency: cryptocurrency, interval: '1m')
                           .order(timestamp: :desc)
                           .limit(5)
                           .reverse
        end
        
        if candles.any?
          candle_array = candles.map do |candle|
            {
              open: candle.open_price,
              high: candle.high_price,
              low: candle.low_price,
              close: candle.close_price,
              timestamp: candle.timestamp,
              isGreen: candle.close_price > candle.open_price
            }
          end
          
          # Sende über ActionCable
          ActionCable.server.broadcast("prices", {
            cryptocurrency_id: cryptocurrency.id,
            symbol: cryptocurrency.symbol,
            type: 'candle_update',
            candles: candle_array,
            timestamp: Time.now.iso8601
          })
          
          Rails.logger.debug "[OK] #{Time.now.strftime('%H:%M:%S')} Candlestick-Update gesendet für #{cryptocurrency.symbol} (#{candles.length} Kerzen)"
        else
          Rails.logger.debug "[!] Keine Kerzendaten gefunden für #{cryptocurrency.symbol}"
        end
        
      rescue => e
        Rails.logger.error "[X] Fehler beim Candlestick-Update für #{cryptocurrency.symbol}: #{e.class} - #{e.message}"
      end
    end
    
    Rails.logger.info "[OK] Minütliches Candlestick-Update abgeschlossen"
    
  rescue => e
    Rails.logger.error "[X] Fehler beim minütlichen Candlestick-Update: #{e.class} - #{e.message}"
  end
end

# --- Modul-Funktion für Rails-Integration ---
# Diese Funktion kann von Rails aufgerufen werden, um den Service zu starten
def start_binance_websocket_service
  console_safe_log "🚀 Starte Binance WebSocket Service..."
  
  # DEBUG-AUSGABE zum Testen
  console_safe_log "🔧 DEBUG_MODE: #{DEBUG_MODE}"
  console_safe_log "🔧 VERBOSE_LOGGING: #{VERBOSE_LOGGING}"
  console_safe_log "🔧 Rails.logger verfügbar: #{!Rails.logger.nil?}"
  
  # Starte Market Cap Updates in separatem Thread
  Thread.new do
    console_safe_log "[Grafik] Starte Market Cap Update Timer..."
    
    loop do
      begin
        MarketCapService.fetch_market_cap_data
        sleep MARKET_CAP_UPDATE_INTERVAL
      rescue => e
        Rails.logger.error "[X] Fehler im Market Cap Update Timer: #{e.class} - #{e.message}"
        sleep 60 # Warte 1 Minute bei Fehler
      end
    end
  end
  
  # Starte Zähler-Ausgabe Timer in separatem Thread
  Thread.new do
    console_safe_log "[Grafik] Starte WebSocket Zähler Timer..."
    
    loop do
      begin
        log_websocket_counters
        sleep 10 # Alle 10 Sekunden Zähler ausgeben
      rescue => e
        Rails.logger.error "[X] Fehler im Zähler Timer: #{e.class} - #{e.message}"
        sleep 60 # Warte 10 Sekunden bei Fehler
      end
    end
  end
  
  # Starte minütliches Candlestick-Update Timer in separatem Thread
  Thread.new do
    console_safe_log "[Kerze] Starte minütliches Candlestick-Update Timer..."
    
    loop do
      begin
        broadcast_all_candlesticks_update
        sleep CANDLESTICK_UPDATE_INTERVAL
      rescue => e
        Rails.logger.error "[X] Fehler im Candlestick-Update Timer: #{e.class} - #{e.message}"
        sleep 60 # Warte 1 Minute bei Fehler
      end
    end
  end
  
  # Haupt-WebSocket Loop mit verbesserter Reconnect-Logik
  reconnect_attempts = 0
  last_successful_connection = Time.now
  
  loop do
    begin
      Rails.logger.info "[REFRESH] Starte WebSocket Verbindung (Versuch #{reconnect_attempts + 1})..."
      
      # Lade Paare aus der Konfiguration
      pairs = PairSelector.load_pairs
      
      if pairs.empty?
        Rails.logger.error "[X] Keine Paare gefunden. Beende Service."
        break
      end
      
      # Erstelle WebSocket URL für alle Paare mit 1m Timeframe (für Echtzeit-Updates)
      stream_names = pairs.map { |pair| "#{pair}@kline_1m" }
      ws_url = "#{BINANCE_WS_BASE_URL}/#{stream_names.join('/')}"
      
      Rails.logger.info "[->] Verbinde mit: #{ws_url}"
      
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
          Rails.logger.info "[OK] WebSocket Verbindung geöffnet"
          last_successful_connection = Time.now
          reconnect_attempts = 0 # Reset Reconnect-Zähler bei erfolgreicher Verbindung
          last_pong_received = Time.now
          ping_interval_thread = start_ping_monitor(ws)
        end
        
        ws.on :error do |e|
          Rails.logger.error "[X] WebSocket Fehler: #{e.message}"
        end
        
        ws.on :close do |e|
          Rails.logger.warn "[!] WebSocket Verbindung geschlossen: #{e.code} - #{e.reason}"
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
          Rails.logger.error "[X] WebSocket.run Fehler: #{e.class} - #{e.message}"
        end
        
      rescue => e
        Rails.logger.error "[X] WebSocket Verbindungsfehler: #{e.class} - #{e.message}"
      end
      
    rescue => e
      reconnect_attempts += 1
      Rails.logger.error "[X] WebSocket Service Fehler (Versuch #{reconnect_attempts}): #{e.class} - #{e.message}"
      
      # Exponentieller Backoff mit Maximum
      delay = [RECONNECT_INITIAL_DELAY_SECONDS * (2 ** (reconnect_attempts - 1)), RECONNECT_MAX_DELAY_SECONDS].min
      
      if reconnect_attempts >= MAX_RECONNECT_ATTEMPTS
        Rails.logger.error "[X] Maximale Reconnect-Versuche erreicht. Pausiere für 5 Minuten..."
        sleep 300 # 5 Minuten Pause
        reconnect_attempts = 0 # Reset für nächsten Zyklus
      else
        Rails.logger.info "⏳ Warte #{delay} Sekunden vor Reconnect (Versuch #{reconnect_attempts + 1})..."
        sleep delay
      end
    end
  end
end