require 'httparty'

class BinanceService
  include HTTParty
  base_uri 'https://api.binance.com'

  def self.fetch_and_update_all_cryptos
    puts "Starting to fetch cryptocurrency data from Binance..."
    
    # Alle verfügbaren Trading-Paare abrufen
    symbols = fetch_all_symbols
    return unless symbols

    puts "Found #{symbols.length} trading pairs"
    
    # Nur USDC-Paare verwenden (stabilere Referenz als USDT)
    usdc_symbols = symbols.select { |symbol| symbol.end_with?('USDC') }
    puts "Processing #{usdc_symbols.length} USDC pairs"

    # Preise für alle Symbole abrufen
    prices = fetch_all_prices
    return unless prices

    # 24h Ticker für Volumen-Daten
    tickers_24h = fetch_24h_tickers
    
    # Für jedes Symbol Daten verarbeiten
    usdc_symbols.each_with_index do |symbol, index|
      begin
        puts "Processing #{symbol} (#{index + 1}/#{usdc_symbols.length})"
        
        # Preis finden
        price_data = prices.find { |p| p['symbol'] == symbol }
        next unless price_data

        # 24h Ticker für Volumen
        ticker_24h = tickers_24h.find { |t| t['symbol'] == symbol }
        volume_24h = ticker_24h ? ticker_24h['volume'].to_f : 0

        # RSI berechnen (1h Timeframe)
        rsi = calculate_rsi_for_symbol(symbol, '1h')
        next unless rsi

        # Cryptocurrency in DB finden oder erstellen
        crypto_name = symbol.gsub('USDC', '')
        crypto = find_or_create_cryptocurrency(crypto_name, symbol, price_data['price'].to_f, rsi, volume_24h)
        
        puts "Updated #{crypto.name} - Price: $#{crypto.current_price}, RSI: #{crypto.rsi}, Volume: $#{crypto.volume_24h}"
        
        # Kleine Pause um Rate Limits zu vermeiden
        sleep(0.1)
        
      rescue => e
        puts "Error processing #{symbol}: #{e.message}"
        next
      end
    end

    puts "Finished updating cryptocurrency data!"
  end

  def self.fetch_specific_cryptos(symbols)
    puts "Starting to fetch specific cryptocurrency data from Binance..."
    puts "Processing #{symbols.length} symbols"

    # Preise für alle Symbole abrufen
    prices = fetch_all_prices
    return unless prices

    # 24h Ticker für Volumen-Daten
    tickers_24h = fetch_24h_tickers

    # Für jedes Symbol Daten verarbeiten
    symbols.each_with_index do |symbol, index|
      begin
        puts "Processing #{symbol} (#{index + 1}/#{symbols.length})"
        
        # Preis finden
        price_data = prices.find { |p| p['symbol'] == symbol }
        next unless price_data

        # 24h Ticker für Volumen
        ticker_24h = tickers_24h.find { |t| t['symbol'] == symbol }
        volume_24h = ticker_24h ? ticker_24h['volume'].to_f : 0

        # RSI berechnen (1h Timeframe)
        rsi = calculate_rsi_for_symbol(symbol, '1h')
        next unless rsi

        # Cryptocurrency in DB finden oder erstellen
        crypto_name = symbol.gsub('USDC', '')
        crypto = find_or_create_cryptocurrency(crypto_name, symbol, price_data['price'].to_f, rsi, volume_24h)
        
        puts "Updated #{crypto.name} - Price: $#{crypto.current_price}, RSI: #{crypto.rsi}, Volume: $#{crypto.volume_24h}"
        
        # Kleine Pause um Rate Limits zu vermeiden
        sleep(0.1)
        
      rescue => e
        puts "Error processing #{symbol}: #{e.message}"
        next
      end
    end

    puts "Finished updating cryptocurrency data!"
  end

  def self.get_top_usdc_pairs
    # Top Kryptowährungen als USDC-Paare
    [
      'BTCUSDC', 'ETHUSDC', 'BNBUSDC', 'ADAUSDC', 'SOLUSDC',
      'XRPUSDC', 'DOTUSDC', 'DOGEUSDC', 'AVAXUSDC', 'SHIBUSDC',
      'MATICUSDC', 'LTCUSDC', 'UNIUSDC', 'LINKUSDC', 'ATOMUSDC',
      'XLMUSDC', 'BCHUSDC', 'ALGOUSDC', 'VETUSDC', 'FILUSDC',
      'TRXUSDC', 'ETCUSDC', 'THETAUSDC', 'FTMUSDC', 'HBARUSDC',
      'EOSUSDC', 'AAVEUSDC', 'NEOUSDC', 'MKRUSDC', 'COMPUSDC',
      'YFIUSDC', 'SNXUSDC', 'DASHUSDC', 'ZECUSDC', 'ENJUSDC',
      'MANAUSDC', 'SANDUSDC', 'CHZUSDC', 'BATUSDC', 'ZILUSDC',
      'ICXUSDC', 'ONTUSDC', 'QTUMUSDC', 'ZRXUSDC', 'OMGUSDC',
      'LRCUSDC', 'STORJUSDC', 'CVCUSDC', 'KNCUSDC', 'NEARUSDC',
      'CAKEUSDC', 'AXSUSDC', 'GALAUSDC', 'APEUSDC', 'GMTUSDC'
    ]
  end

  def self.get_historical_data(symbol, interval, start_time)
    puts "Fetching historical data for #{symbol}, interval: #{interval}, start_time: #{start_time}"
    
    # Konvertiere start_time zu Timestamp
    start_timestamp = case start_time
                     when /(\d+) day ago/
                       (Time.current - $1.to_i.days).to_i * 1000
                     when /(\d+) days ago/
                       (Time.current - $1.to_i.days).to_i * 1000
                     else
                       (Time.current - 1.day).to_i * 1000
                     end

    puts "Calculated start_timestamp: #{start_timestamp} (#{Time.at(start_timestamp / 1000)})"

    response = get("/api/v3/klines", query: {
      symbol: symbol,
      interval: interval,
      startTime: start_timestamp,
      limit: 1000
    })

    puts "Binance API response status: #{response.code}"

    if response.success?
      klines = response.parsed_response
      puts "Received #{klines.length} klines for #{symbol}"
      
      if klines.empty?
        puts "No klines data received for #{symbol}"
        return []
      end
      
      # Formatiere Daten für Chart.js
      chart_data = klines.map do |kline|
        {
          time: Time.at(kline[0] / 1000).strftime('%Y-%m-%d %H:%M'),
          timestamp: kline[0],
          open: kline[1].to_f,
          high: kline[2].to_f,
          low: kline[3].to_f,
          close: kline[4].to_f,
          volume: kline[5].to_f
        }
      end
      
      # Berechne RSI für jeden Datenpunkt
      closes = chart_data.map { |data| data[:close] }
      volumes = chart_data.map { |data| data[:volume] }
      rsi_values = calculate_historical_rsi(closes)
      
      # Berechne Moving Averages
      ema_20 = calculate_ema(closes, 20)
      ema_200 = calculate_ema(closes, 200)
      sma_20_volume = calculate_sma(volumes, 20)
      
      # Füge alle Indikatoren zu den Chart-Daten hinzu
      chart_data.each_with_index do |data, index|
        data[:rsi] = rsi_values[index]
        data[:ema_20] = ema_20[index]
        data[:ema_200] = ema_200[index]
        data[:sma_20_volume] = sma_20_volume[index]
      end
      
      puts "Successfully processed #{chart_data.length} data points for #{symbol}"
      chart_data
    else
      puts "Error fetching historical data for #{symbol}: #{response.code} - #{response.message}"
      puts "Response body: #{response.body}" if response.body
      []
    end
  rescue => e
    puts "Exception in get_historical_data for #{symbol}: #{e.message}"
    puts e.backtrace.first(5)
    []
  end

  def self.calculate_historical_rsi(closes, period = 14)
    return [] if closes.length < period + 1
    
    rsi_values = []
    
    # Für die ersten period-1 Werte gibt es keinen RSI
    (period - 1).times { rsi_values << nil }
    
    # Berechne RSI für jeden möglichen Punkt
    (period - 1...closes.length).each do |i|
      subset = closes[0..i]
      next if subset.length < period + 1
      
      rsi = calculate_rsi_wilders(subset, period)
      rsi_values << rsi
    end
    
    rsi_values
  end

  private

  def self.fetch_all_symbols
    response = get('/api/v3/exchangeInfo')
    if response.success?
      symbols = response.parsed_response['symbols']
                       .select { |s| s['status'] == 'TRADING' }
                       .map { |s| s['symbol'] }
      symbols
    else
      puts "Error fetching symbols: #{response.code} - #{response.message}"
      nil
    end
  end

  def self.fetch_all_prices
    response = get('/api/v3/ticker/price')
    if response.success?
      response.parsed_response
    else
      puts "Error fetching prices: #{response.code} - #{response.message}"
      nil
    end
  end

  def self.fetch_24h_tickers
    response = get('/api/v3/ticker/24hr')
    if response.success?
      response.parsed_response
    else
      puts "Error fetching 24h tickers: #{response.code} - #{response.message}"
      []
    end
  end

  def self.calculate_rsi_for_symbol(symbol, interval = '1h', period = 14)
    # Mehr Kline-Daten für genauere RSI-Berechnung abrufen
    response = get("/api/v3/klines", query: {
      symbol: symbol,
      interval: interval,
      limit: 100 # Deutlich mehr Daten für bessere Genauigkeit
    })

    if response.success?
      klines = response.parsed_response
      closes = klines.map { |kline| kline[4].to_f } # Schlusskurse
      
      return nil if closes.length < period + 1
      
      calculate_rsi_wilders(closes, period)
    else
      puts "Error fetching klines for #{symbol}: #{response.code}"
      nil
    end
  end

  def self.calculate_rsi(closes, period = 14)
    return nil if closes.length < period + 1

    gains = []
    losses = []

    # Berechne Gewinne und Verluste
    (1...closes.length).each do |i|
      change = closes[i] - closes[i-1]
      if change > 0
        gains << change
        losses << 0
      else
        gains << 0
        losses << change.abs
      end
    end

    return nil if gains.length < period

    # Erste durchschnittliche Gewinne und Verluste (SMA)
    avg_gain = gains.first(period).sum / period
    avg_loss = losses.first(period).sum / period

    # Smoothed RSI für die restlichen Werte (EMA-ähnlich)
    (period...gains.length).each do |i|
      avg_gain = ((avg_gain * (period - 1)) + gains[i]) / period
      avg_loss = ((avg_loss * (period - 1)) + losses[i]) / period
    end

    return 50 if avg_loss == 0 # Vermeidung von Division durch Null

    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    rsi.round(2)
  end

  # Wilder's RSI-Berechnung (Standard-Methode, genauer)
  def self.calculate_rsi_wilders(closes, period = 14)
    return nil if closes.length < period + 1

    gains = []
    losses = []

    # Berechne Gewinne und Verluste
    (1...closes.length).each do |i|
      change = closes[i] - closes[i-1]
      gains << (change > 0 ? change : 0)
      losses << (change < 0 ? change.abs : 0)
    end

    return nil if gains.length < period

    # Erste Durchschnitte (SMA für die ersten 14 Werte)
    avg_gain = gains.first(period).sum / period
    avg_loss = losses.first(period).sum / period

    # Wilder's Smoothing (echte EMA mit Alpha = 1/period)
    alpha = 1.0 / period
    (period...gains.length).each do |i|
      avg_gain = alpha * gains[i] + (1 - alpha) * avg_gain
      avg_loss = alpha * losses[i] + (1 - alpha) * avg_loss
    end

    return 50 if avg_loss == 0

    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    rsi.round(2)
  end

  def self.find_or_create_cryptocurrency(name, symbol, price, rsi, volume_24h = 0)
    # Market Cap berechnen basierend auf geschätzter Coin Supply
    estimated_supply = estimate_coin_supply(name.upcase)
    market_cap_usd = price * estimated_supply

    # Verwende das vollständige Trading-Pair als Symbol
    crypto = Cryptocurrency.find_or_initialize_by(symbol: symbol.upcase)
    
    crypto.assign_attributes(
      name: format_crypto_name(name),
      symbol: symbol.upcase, # Vollständiges Trading-Pair (z.B. BTCUSDC)
      current_price: price,
      market_cap: market_cap_usd,
      rsi: rsi,
      volume_24h: volume_24h * price, # Volumen in USD
      market_cap_rank: crypto.persisted? ? crypto.market_cap_rank : Cryptocurrency.count + 1,
      updated_at: Time.current
    )

    crypto.save!
    crypto
  end

  def self.estimate_coin_supply(symbol)
    # Geschätzte Coin Supply für Market Cap Berechnung (in USD)
    supply_mapping = {
      'BTC' => 19_700_000,      # Bitcoin
      'ETH' => 120_000_000,     # Ethereum
      'BNB' => 150_000_000,     # Binance Coin
      'ADA' => 35_000_000_000,  # Cardano
      'SOL' => 400_000_000,     # Solana
      'XRP' => 50_000_000_000,  # Ripple
      'DOT' => 1_200_000_000,   # Polkadot
      'DOGE' => 140_000_000_000, # Dogecoin
      'AVAX' => 400_000_000,    # Avalanche
      'SHIB' => 550_000_000_000_000, # Shiba Inu
      'MATIC' => 10_000_000_000, # Polygon
      'LTC' => 75_000_000,      # Litecoin
      'UNI' => 1_000_000_000,   # Uniswap
      'LINK' => 1_000_000_000,  # Chainlink
      'ATOM' => 300_000_000,    # Cosmos
      'XLM' => 25_000_000_000,  # Stellar
      'BCH' => 19_700_000,      # Bitcoin Cash
      'ALGO' => 10_000_000_000, # Algorand
      'VET' => 86_000_000_000,  # VeChain
      'FIL' => 400_000_000,     # Filecoin
      'CAKE' => 400_000_000,    # PancakeSwap
      'AXS' => 270_000_000,     # Axie Infinity
      'GALA' => 35_000_000_000, # Gala
      'APE' => 1_000_000_000,   # ApeCoin
      'GMT' => 6_000_000_000    # STEPN
    }

    supply_mapping[symbol] || 1_000_000 # Default für unbekannte Coins
  end

  def self.format_crypto_name(symbol)
    # Bekannte Kryptowährungen mit richtigen Namen
    name_mapping = {
      'BTC' => 'Bitcoin',
      'ETH' => 'Ethereum',
      'BNB' => 'Binance Coin',
      'ADA' => 'Cardano',
      'SOL' => 'Solana',
      'XRP' => 'Ripple',
      'DOT' => 'Polkadot',
      'DOGE' => 'Dogecoin',
      'AVAX' => 'Avalanche',
      'SHIB' => 'Shiba Inu',
      'MATIC' => 'Polygon',
      'LTC' => 'Litecoin',
      'UNI' => 'Uniswap',
      'LINK' => 'Chainlink',
      'ATOM' => 'Cosmos',
      'XLM' => 'Stellar',
      'BCH' => 'Bitcoin Cash',
      'ALGO' => 'Algorand',
      'VET' => 'VeChain',
      'FIL' => 'Filecoin',
      'TRX' => 'Tron',
      'ETC' => 'Ethereum Classic',
      'XMR' => 'Monero',
      'THETA' => 'Theta Network',
      'FTM' => 'Fantom',
      'HBAR' => 'Hedera',
      'EOS' => 'EOS',
      'AAVE' => 'Aave',
      'NEO' => 'Neo',
      'MKR' => 'Maker',
      'COMP' => 'Compound',
      'YFI' => 'Yearn.finance',
      'SNX' => 'Synthetix',
      'DASH' => 'Dash',
      'ZEC' => 'Zcash',
      'ENJ' => 'Enjin Coin',
      'MANA' => 'Decentraland',
      'SAND' => 'The Sandbox',
      'CHZ' => 'Chiliz',
      'BAT' => 'Basic Attention Token',
      'ZIL' => 'Zilliqa',
      'ICX' => 'ICON',
      'ONT' => 'Ontology',
      'QTUM' => 'Qtum',
      'ZRX' => '0x',
      'OMG' => 'OMG Network',
      'LRC' => 'Loopring',
      'STORJ' => 'Storj',
      'CVC' => 'Civic',
      'KNC' => 'Kyber Network',
      'NEAR' => 'NEAR Protocol',
      'CAKE' => 'PancakeSwap',
      'AXS' => 'Axie Infinity',
      'GALA' => 'Gala',
      'APE' => 'ApeCoin',
      'GMT' => 'STEPN'
    }

    name_mapping[symbol.upcase] || symbol.capitalize
  end

  def self.calculate_ema(closes, period)
    return [] if closes.length < period
    
    ema = []
    smoothing = 2.0 / (period + 1)
    
    # Für die ersten period-1 Werte gibt es keinen EMA
    (period - 1).times { ema << nil }
    
    # Erste EMA ist der SMA der ersten period Werte
    first_sma = closes[0...period].sum / period.to_f
    ema << first_sma
    
    # Berechne EMA für die restlichen Werte
    (period...closes.length).each do |i|
      ema << (closes[i] - ema.last) * smoothing + ema.last
    end
    
    ema
  end

  def self.calculate_sma(values, period)
    return [] if values.length < period
    
    sma = []
    
    # Für die ersten period-1 Werte gibt es keinen SMA
    (period - 1).times { sma << nil }
    
    # Berechne SMA für jeden möglichen Punkt
    (period - 1...values.length).each do |i|
      subset = values[(i - period + 1)..i]
      sma << subset.sum / period.to_f
    end
    
    sma
  end
end 