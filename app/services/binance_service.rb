require 'httparty'

class BinanceService
  include HTTParty
  base_uri 'https://api.binance.com'
  
  # Konfiguration direkt im Service
  ROC_PERIOD = 14
  RSI_PERIOD = 14
  DEFAULT_INTERVAL = '1h'

  # Binance Logger für separate Logdatei
  def self.binance_logger
    @binance_logger ||= begin
      log_file = Rails.root.join('log', 'binance.log')
      # Stelle sicher, dass das Log-Verzeichnis existiert
      FileUtils.mkdir_p(File.dirname(log_file)) unless Dir.exist?(File.dirname(log_file))
      
      # Verwende sowohl separate Datei als auch Rails Logger als Fallback
      logger = Logger.new(log_file)
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
      end
      
      # Schreibe auch in Rails Logger für Debugging
      Rails.logger.info("BINANCE LOGGER: Initialized binance.log at #{log_file}")
      
      logger
    rescue => e
      # Fallback auf Rails Logger
      Rails.logger.error("BINANCE LOGGER ERROR: #{e.message}")
      Rails.logger
    end
  end

  def self.log_binance_request(endpoint, params = {}, response_code = nil, response_body = nil)
    log_message = "BINANCE API REQUEST: #{endpoint}"
    log_message += " | Params: #{params}" unless params.empty?
    log_message += " | Response: #{response_code}" if response_code
    log_message += " | Body: #{response_body}" if response_body && response_body.length < 500
    
    # Schreibe in beide Logger
    binance_logger.info(log_message)
    Rails.logger.info(log_message)
    
    # Direktes Schreiben in Datei als Backup
    write_direct_to_log(log_message)
  end

  def self.log_binance_error(endpoint, error_message)
    log_message = "BINANCE API ERROR: #{endpoint} | Error: #{error_message}"
    
    # Schreibe in beide Logger
    binance_logger.error(log_message)
    Rails.logger.error(log_message)
    
    # Direktes Schreiben in Datei als Backup
    write_direct_to_log(log_message)
  end

  def self.log_binance_success(endpoint, message)
    log_message = "BINANCE API SUCCESS: #{endpoint} | #{message}"
    
    # Schreibe in beide Logger
    binance_logger.info(log_message)
    Rails.logger.info(log_message)
    
    # Direktes Schreiben in Datei als Backup
    write_direct_to_log(log_message)
  end

  # Direktes Schreiben in die Logdatei als Backup
  def self.write_direct_to_log(message)
    begin
      log_file = Rails.root.join('log', 'binance.log')
      File.open(log_file, 'a') do |f|
        f.puts "#{Time.current.strftime('%Y-%m-%d %H:%M:%S')} [INFO] #{message}"
      end
    rescue => e
      Rails.logger.error("Failed to write to binance.log: #{e.message}")
    end
  end

  # Detailliertes Logging aller API-Antworten
  def self.log_binance_response_data(endpoint, response_data, symbol = nil)
    if response_data.is_a?(Array)
      # Für Arrays (z.B. Klines-Daten)
      log_message = "BINANCE API RESPONSE DATA: #{endpoint}"
      log_message += " | Symbol: #{symbol}" if symbol
      log_message += " | Data Count: #{response_data.length}"
      
      binance_logger.info(log_message)
      write_direct_to_log(log_message)
      
      # Logge alle Daten detailliert
      response_data.each_with_index do |item, index|
        if item.is_a?(Array) && item.length >= 6
          kline_data = {
            index: index,
            timestamp: Time.at(item[0] / 1000).strftime('%Y-%m-%d %H:%M:%S'),
            open: item[1].to_f,
            high: item[2].to_f,
            low: item[3].to_f,
            close: item[4].to_f,
            volume: item[5].to_f
          }
          data_log = "BINANCE KLINE DATA: #{symbol} | #{kline_data}"
          binance_logger.info(data_log)
          write_direct_to_log(data_log)
        elsif item.is_a?(Hash)
          data_log = "BINANCE RESPONSE ITEM: #{symbol} | #{item}"
          binance_logger.info(data_log)
          write_direct_to_log(data_log)
        end
      end
      
    elsif response_data.is_a?(Hash)
      # Für Hash-Daten (z.B. Ticker-Daten)
      log_message = "BINANCE API RESPONSE DATA: #{endpoint}"
      log_message += " | Symbol: #{symbol}" if symbol
      log_message += " | Data: #{response_data}"
      
      binance_logger.info(log_message)
      write_direct_to_log(log_message)
    end
  end

  # Test-Methode um das Logging zu überprüfen
  def self.test_logging
    binance_logger.info("BINANCE LOGGER TEST: Logger is working properly")
    
    # Direktes Schreiben in die Datei als zusätzlicher Test
    log_file = Rails.root.join('log', 'binance.log')
    File.open(log_file, 'a') do |f|
      f.puts "#{Time.current.strftime('%Y-%m-%d %H:%M:%S')} [INFO] DIRECT WRITE TEST: Writing directly to binance.log"
    end
    
    puts "Test logs written to binance.log"
  end

  def self.fetch_and_update_all_cryptos
    # Test-Log beim ersten Aufruf
    binance_logger.info("BINANCE SERVICE: Starting fetch_and_update_all_cryptos")
    puts "Starting to fetch cryptocurrency data from Binance..."
    
    # Alle verfügbaren Trading-Paare abrufen
    symbols = fetch_all_symbols
    return unless symbols

    puts "Found #{symbols.length} trading pairs"
    
    # Nur USDC-Paare verwenden (stabilere Referenz als USDT)
    usdc_symbols = symbols.select { |symbol| symbol.end_with?('USDC') }
    puts "Processing #{usdc_symbols.length} USDC pairs"

    # Preise für USDC-Paare abrufen
    prices = fetch_prices_for_symbols(usdc_symbols)
    return unless prices

    # 24h Ticker für Volumen-Daten (nur für USDC-Paare)
    tickers_24h = fetch_24h_tickers_for_symbols(usdc_symbols)
    
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
        
        puts "#{Date.now.strftime('%Y-%m-%d %H:%M:%S')} Updated #{crypto.name} - Price: $#{crypto.current_price}, RSI: #{crypto.rsi}, Volume: $#{crypto.volume_24h}"
        
        # Speichere historische Daten (nur für die ersten 10 Coins um Performance zu optimieren)
        if index < 10
          begin
            store_historical_data_for_crypto(crypto, 100) # 100 Perioden
            puts "Stored historical data for #{crypto.name}"
          rescue => e
            puts "Error storing historical data for #{crypto.name}: #{e.message}"
          end
        end
        
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

    # Preise für spezifische Symbole abrufen
    prices = fetch_prices_for_symbols(symbols)
    return unless prices

    # 24h Ticker für Volumen-Daten (nur für spezifische Symbole)
    tickers_24h = fetch_24h_tickers_for_symbols(symbols)

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

    params = {
      symbol: symbol,
      interval: interval,
      startTime: start_timestamp,
      limit: 1000
    }
    log_binance_request('/api/v3/klines', params)
    
    response = get("/api/v3/klines", query: params)

    puts "Binance API response status: #{response.code}"

    if response.success?
      klines = response.parsed_response
      puts "Received #{klines.length} klines for #{symbol}"
      log_binance_success('/api/v3/klines', "Retrieved #{klines.length} historical klines for #{symbol}")
      log_binance_response_data('/api/v3/klines', klines, symbol)
      
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
      
          # Berechne RSI für mehrere Zeitrahmen (15m, 1h)
    multi_rsi_values = get_multi_timeframe_rsi_for_chart_data(symbol, chart_data)
    
    # Berechne ROC für mehrere Zeitrahmen (15m, 1h)
    multi_roc_values = get_multi_timeframe_roc_for_chart_data(symbol, chart_data)
    
    # Berechne ROC-Ableitung für mehrere Zeitrahmen (15m, 1h)
    multi_roc_derivative_values = get_multi_timeframe_roc_derivative_for_chart_data(symbol, chart_data)
      
      # Berechne Moving Averages basierend auf Chart-Daten
      closes = chart_data.map { |data| data[:close] }
      volumes = chart_data.map { |data| data[:volume] }
      ema_20 = calculate_ema(closes, 20)
      ema_200 = calculate_ema(closes, 200)
      sma_20_volume = calculate_sma(volumes, 20)
      
      # Füge alle Indikatoren zu den Chart-Daten hinzu
      chart_data.each_with_index do |data, index|
        data[:rsi_15m] = multi_rsi_values['15m'][index]
        data[:rsi_1h] = multi_rsi_values['1h'][index]
        data[:roc_15m] = multi_roc_values['15m'][index]
        data[:roc_1h] = multi_roc_values['1h'][index]
        data[:roc_derivative_15m] = multi_roc_derivative_values['15m'][index]
        data[:roc_derivative_1h] = multi_roc_derivative_values['1h'][index]
        data[:ema_20] = ema_20[index]
        data[:ema_200] = ema_200[index]
        data[:sma_20_volume] = sma_20_volume[index]
      end
      
      puts "Successfully processed #{chart_data.length} data points for #{symbol}"
      chart_data
    else
      log_binance_error('/api/v3/klines', "HTTP #{response.code} for #{symbol}: #{response.message}")
      puts "Error fetching historical data for #{symbol}: #{response.code} - #{response.message}"
      puts "Response body: #{response.body}" if response.body
      []
    end
  rescue => e
    puts "Exception in get_historical_data for #{symbol}: #{e.message}"
    puts e.backtrace.first(5)
    []
  end

  # Neue Methode: Hole 1h RSI-Daten und mappe sie auf Chart-Zeitpunkte
  def self.get_1h_rsi_for_chart_data(symbol, chart_data)
    puts "Fetching 1h RSI data for #{symbol}"
    
    # Hole 1h-Daten für RSI-Berechnung (mehr Daten für bessere Genauigkeit)
    start_time_1h = (Time.current - 30.days).to_i * 1000
    
    response = get("/api/v3/klines", query: {
      symbol: symbol,
      interval: '1h',
      startTime: start_time_1h,
      limit: 1000
    })

    if response.success?
      klines_1h = response.parsed_response
      puts "Received #{klines_1h.length} 1h klines for RSI calculation"
      
      # Berechne RSI auf 1h-Basis
      closes_1h = klines_1h.map { |kline| kline[4].to_f }
      rsi_1h_values = calculate_historical_rsi(closes_1h)
      
      # Erstelle Mapping von Zeitstempel zu RSI-Werten
      rsi_map = {}
      klines_1h.each_with_index do |kline, index|
        timestamp_1h = kline[0]
        rsi_map[timestamp_1h] = rsi_1h_values[index]
      end
      
      # Mappe RSI-Werte auf Chart-Datenpunkte
      chart_data.map do |data_point|
        chart_timestamp = data_point[:timestamp]
        
        # Finde den nächstgelegenen 1h-Zeitstempel
        closest_1h_timestamp = find_closest_1h_timestamp(chart_timestamp, rsi_map.keys)
        rsi_map[closest_1h_timestamp]
      end
    else
      puts "Error fetching 1h data for RSI: #{response.code}"
      # Fallback: Verwende Chart-Daten für RSI (nicht ideal, aber besser als nichts)
      closes = chart_data.map { |data| data[:close] }
      calculate_historical_rsi(closes)
    end
  rescue => e
    puts "Exception in get_1h_rsi_for_chart_data: #{e.message}"
    # Fallback: Verwende Chart-Daten für RSI
    closes = chart_data.map { |data| data[:close] }
    calculate_historical_rsi(closes)
  end

  # Hilfsmethode: Finde den nächstgelegenen 1h-Zeitstempel
  def self.find_closest_1h_timestamp(target_timestamp, available_timestamps)
    return available_timestamps.first if available_timestamps.empty?
    
    available_timestamps.min_by { |ts| (ts - target_timestamp).abs }
  end

  def self.calculate_historical_rsi(closes, period = RSI_PERIOD)
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

  # Neue Methode: Hole RSI-Daten für mehrere Zeitrahmen (15m, 1h)
  def self.get_multi_timeframe_rsi_for_chart_data(symbol, chart_data)
    puts "Fetching multi-timeframe RSI data for #{symbol} (15m, 1h)"
    
    rsi_data = {}
    timeframes = ['15m', '1h']
    
    timeframes.each do |timeframe|
      puts "Fetching #{timeframe} RSI data for #{symbol}"
      
      # Bestimme wie viele Tage zurück wir gehen müssen
      days_back = case timeframe
                  when '15m' then 7  # 7 Tage für 15m
                  when '1h' then 30  # 30 Tage für 1h
                  end
      
      start_time_tf = (Time.current - days_back.days).to_i * 1000
      
      response = get("/api/v3/klines", query: {
        symbol: symbol,
        interval: timeframe,
        startTime: start_time_tf,
        limit: 1000
      })

      if response.success?
        klines_tf = response.parsed_response
        puts "Received #{klines_tf.length} #{timeframe} klines for RSI calculation"
        
        # Berechne RSI für diesen Zeitrahmen
        closes_tf = klines_tf.map { |kline| kline[4].to_f }
        rsi_tf_values = calculate_historical_rsi(closes_tf)
        
        # Debug für 1m-Daten
        if timeframe == '1m'
          valid_rsi_count = rsi_tf_values.compact.length
          puts "1m RSI calculation: #{rsi_tf_values.length} total values, #{valid_rsi_count} valid (non-null) values"
          puts "First 5 RSI values: #{rsi_tf_values.first(5)}"
          puts "Last 5 RSI values: #{rsi_tf_values.last(5)}"
        end
        
        # Erstelle Mapping von Zeitstempel zu RSI-Werten
        rsi_map_tf = {}
        klines_tf.each_with_index do |kline, index|
          timestamp_tf = kline[0]
          rsi_map_tf[timestamp_tf] = rsi_tf_values[index]
        end
        
        # Mappe RSI-Werte auf Chart-Datenpunkte
        rsi_data[timeframe] = chart_data.map do |data_point|
          chart_timestamp = data_point[:timestamp]
          
          # Für 1m-Daten: Verwende Interpolation wenn nötig
          if timeframe == '1m'
            rsi_value = interpolate_rsi_value(chart_timestamp, rsi_map_tf, timeframe)
          else
            # Für 15m und 1h: Normale Zuordnung
            closest_timestamp = find_closest_timestamp_for_timeframe(chart_timestamp, rsi_map_tf.keys, timeframe)
            rsi_value = rsi_map_tf[closest_timestamp]
          end
          
          # Debug für 1m-Daten
          if timeframe == '1m' && chart_data.index(data_point) < 3
            puts "1m RSI mapping #{chart_data.index(data_point)}: chart_ts=#{Time.at(chart_timestamp/1000)}, rsi=#{rsi_value}"
          end
          
          rsi_value
        end
        
        puts "Successfully mapped #{timeframe} RSI data - #{rsi_data[timeframe].compact.length} valid values out of #{rsi_data[timeframe].length} total"
      else
        puts "Error fetching #{timeframe} data for RSI: #{response.code}"
        # Fallback: Verwende Chart-Daten für RSI
        closes = chart_data.map { |data| data[:close] }
        rsi_data[timeframe] = calculate_historical_rsi(closes)
      end
    end
    
    rsi_data
  rescue => e
    puts "Exception in get_multi_timeframe_rsi_for_chart_data: #{e.message}"
    # Fallback: Verwende Chart-Daten für alle Zeitrahmen
    closes = chart_data.map { |data| data[:close] }
    fallback_rsi = calculate_historical_rsi(closes)
    {
      '1m' => fallback_rsi,
      '15m' => fallback_rsi,
      '1h' => fallback_rsi
    }
  end

  # Hilfsmethode: Finde den nächstgelegenen Zeitstempel für einen bestimmten Zeitrahmen
  def self.find_closest_timestamp_for_timeframe(target_timestamp, available_timestamps, timeframe)
    return available_timestamps.first if available_timestamps.empty?
    
    # Für verschiedene Zeitrahmen unterschiedliche Toleranzen (erhöht für bessere Zuordnung)
    tolerance = case timeframe
                when '1m' then 300_000     # 5 Minuten Toleranz für 1m (erhöht)
                when '15m' then 1_800_000  # 30 Minuten Toleranz für 15m (erhöht)
                when '1h' then 7_200_000   # 2 Stunden Toleranz für 1h (erhöht)
                end
    
    # Finde den nächstgelegenen Zeitstempel
    closest = available_timestamps.min_by { |ts| (ts - target_timestamp).abs }
    time_diff = (closest - target_timestamp).abs
    
    puts "#{timeframe} mapping: target=#{Time.at(target_timestamp/1000)}, closest=#{Time.at(closest/1000)}, diff=#{time_diff/1000}s, tolerance=#{tolerance/1000}s"
    
    # Gib immer den nächstgelegenen Zeitstempel zurück, auch wenn er außerhalb der Toleranz liegt
    # Das verhindert, dass RSI-Werte komplett fehlen
    closest
  end

  def self.update_roc_for_all_cryptocurrencies
    Cryptocurrency.find_each do |crypto|
      begin
        roc = calculate_roc_for_symbol(crypto.symbol, '1h')
        roc_derivative = calculate_roc_derivative_for_symbol(crypto.symbol, '1h')
        
        if roc || roc_derivative
          Cryptocurrency.where(id: crypto.id).update_all(
            roc: roc,
            roc_derivative: roc_derivative
          )
        end
        
        # Kleine Pause um Rate Limits zu vermeiden
        sleep(0.1)
        
      rescue => e
        # Stille Fehlerbehandlung
        next
      end
    end
  end

  private

  def self.fetch_all_symbols
    log_binance_request('/api/v3/exchangeInfo')
    response = get('/api/v3/exchangeInfo')
    
    if response.success?
      symbols = response.parsed_response['symbols']
                       .select { |s| s['status'] == 'TRADING' }
                       .map { |s| s['symbol'] }
      log_binance_success('/api/v3/exchangeInfo', "Retrieved #{symbols.length} trading symbols")
      log_binance_response_data('/api/v3/exchangeInfo', response.parsed_response['symbols'])
      symbols
    else
      log_binance_error('/api/v3/exchangeInfo', "HTTP #{response.code}: #{response.message}")
      puts "Error fetching symbols: #{response.code} - #{response.message}"
      nil
    end
  end

  def self.fetch_all_prices
    log_binance_request('/api/v3/ticker/price')
    response = get('/api/v3/ticker/price')
    if response.success?
      log_binance_success('/api/v3/ticker/price', "Retrieved #{response.parsed_response.length} price entries")
      log_binance_response_data('/api/v3/ticker/price', response.parsed_response)
      response.parsed_response
    else
      log_binance_error('/api/v3/ticker/price', "HTTP #{response.code}: #{response.message}")
      puts "Error fetching prices: #{response.code} - #{response.message}"
      nil
    end
  end

  # Optimierte Methode: Hole alle Preise und filtere nach spezifischen Symbolen
  def self.fetch_prices_for_symbols(symbols)
    return [] if symbols.empty?
    
    log_binance_request('/api/v3/ticker/price')
    response = get('/api/v3/ticker/price')
    
    if response.success?
      all_prices = response.parsed_response
      # Filtere nur die gewünschten Symbole
      filtered_prices = all_prices.select { |price| symbols.include?(price['symbol']) }
      
      log_binance_success('/api/v3/ticker/price', "Retrieved #{filtered_prices.length} price entries for #{symbols.length} symbols (filtered from #{all_prices.length} total)")
      log_binance_response_data('/api/v3/ticker/price', filtered_prices)
      filtered_prices
    else
      log_binance_error('/api/v3/ticker/price', "HTTP #{response.code}: #{response.message}")
      puts "Error fetching prices for symbols: #{response.code} - #{response.message}"
      []
    end
  end

  def self.fetch_24h_tickers
    log_binance_request('/api/v3/ticker/24hr')
    response = get('/api/v3/ticker/24hr')
    if response.success?
      log_binance_success('/api/v3/ticker/24hr', "Retrieved #{response.parsed_response.length} 24h ticker entries")
      log_binance_response_data('/api/v3/ticker/24hr', response.parsed_response)
      response.parsed_response
    else
      log_binance_error('/api/v3/ticker/24hr', "HTTP #{response.code}: #{response.message}")
      puts "Error fetching 24h tickers: #{response.code} - #{response.message}"
      []
    end
  end

  # Optimierte Methode: Hole alle 24h Ticker und filtere nach spezifischen Symbolen
  def self.fetch_24h_tickers_for_symbols(symbols)
    return [] if symbols.empty?
    
    log_binance_request('/api/v3/ticker/24hr')
    response = get('/api/v3/ticker/24hr')
    
    if response.success?
      all_tickers = response.parsed_response
      # Filtere nur die gewünschten Symbole
      filtered_tickers = all_tickers.select { |ticker| symbols.include?(ticker['symbol']) }
      
      log_binance_success('/api/v3/ticker/24hr', "Retrieved #{filtered_tickers.length} 24h ticker entries for #{symbols.length} symbols (filtered from #{all_tickers.length} total)")
      log_binance_response_data('/api/v3/ticker/24hr', filtered_tickers)
      filtered_tickers
    else
      log_binance_error('/api/v3/ticker/24hr', "HTTP #{response.code}: #{response.message}")
      puts "Error fetching 24h tickers for symbols: #{response.code} - #{response.message}"
      []
    end
  end

  def self.calculate_rsi_for_symbol(symbol, interval = DEFAULT_INTERVAL, period = RSI_PERIOD)
    # Mehr Kline-Daten für genauere RSI-Berechnung abrufen
    params = { symbol: symbol, interval: interval, limit: 14 }
    log_binance_request('/api/v3/klines', params)
    
    response = get("/api/v3/klines", query: params)

    if response.success?
      klines = response.parsed_response
      closes = klines.map { |kline| kline[4].to_f } # Schlusskurse
      
      log_binance_success('/api/v3/klines', "Retrieved #{klines.length} klines for #{symbol} RSI calculation")
      log_binance_response_data('/api/v3/klines', klines, symbol)
      
      return nil if closes.length < period + 1
      
      calculate_rsi_wilders(closes, period)
    else
      log_binance_error('/api/v3/klines', "HTTP #{response.code} for #{symbol}: #{response.message}")
      puts "Error fetching klines for #{symbol}: #{response.code}"
      nil
    end
  end

  def self.calculate_rsi(closes, period = RSI_PERIOD)
    return nil if closes.length < period + 1

    gains = []
    losses = []

    # Berechne Gewinne und Verluste
    (1...closes.length).each do |i|
      logger.info("Debug: closes[#{i}]: #{closes[i]} - #{closes[i-1]} ")
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
  def self.calculate_rsi_wilders(closes, period = RSI_PERIOD)
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

  # ROC (Rate of Change) Berechnung
  def self.calculate_roc(closes, period = ROC_PERIOD)
    return nil if closes.length < period + 1
    
    # ROC = ((Current Price - Price n periods ago) / Price n periods ago) * 100
    current_price = closes.last
    price_n_periods_ago = closes[closes.length - period - 1]
    
    return nil if price_n_periods_ago.nil? || price_n_periods_ago == 0
    
    roc = ((current_price - price_n_periods_ago) / price_n_periods_ago) * 100
    roc.round(2)
  end

  def self.calculate_roc_derivative(closes, period = ROC_PERIOD)
    return nil if closes.length < period + 2
    
    # Berechne ROC für aktuelle Periode
    current_roc = calculate_roc(closes, period)
    return nil if current_roc.nil?
    
    # Berechne ROC für vorherige Periode (um 1 Periode verschoben)
    previous_closes = closes[0...-1]
    previous_roc = calculate_roc(previous_closes, period)
    return nil if previous_roc.nil?
    
    # ROC-Ableitung = Differenz zwischen aktuellem und vorherigem ROC
    roc_derivative = current_roc - previous_roc
    roc_derivative.round(2)
  end

  def self.calculate_roc_for_symbol(symbol, interval = DEFAULT_INTERVAL, period = ROC_PERIOD)
    # Mehr Kline-Daten für genauere ROC-Berechnung abrufen
    response = get("/api/v3/klines", query: {
      symbol: symbol,
      interval: interval,
      limit: 14  # Minimale Daten für ROC-Berechnung
    })

    if response.success?
      klines = response.parsed_response
      closes = klines.map { |kline| kline[4].to_f }  # Close price ist Index 4
      
      if closes.length >= period + 1
        roc = calculate_roc(closes, period)
        return roc
      else
        return nil
      end
    else
      return nil
    end
  rescue => e
    return nil
  end

  def self.calculate_roc_derivative_for_symbol(symbol, interval = DEFAULT_INTERVAL, period = ROC_PERIOD)
    # Mehr Kline-Daten für genauere ROC-Ableitungs-Berechnung abrufen
    response = get("/api/v3/klines", query: {
      symbol: symbol,
      interval: interval,
      limit: 15  # Minimale Daten für ROC-Ableitungs-Berechnung (15 für 14+1)
    })

    if response.success?
      klines = response.parsed_response
      closes = klines.map { |kline| kline[4].to_f }  # Close price ist Index 4
      
      if closes.length >= period + 2
        roc_derivative = calculate_roc_derivative(closes, period)
        return roc_derivative
      else
        return nil
      end
    else
      return nil
    end
  rescue => e
    return nil
  end

  def self.store_historical_data_for_crypto(cryptocurrency, period = 100)
    puts "Storing historical data for #{cryptocurrency.symbol} (period: #{period})"
    
    intervals = %w[1h 4h 1d] # Verschiedene Intervalle für verschiedene Zeiträume
    
    intervals.each do |interval|
      begin
        # Hole historische Daten von Binance
        start_time = case interval
                    when '1h' then "#{period} hours ago UTC"
                    when '4h' then "#{period * 4} hours ago UTC"
                    when '1d' then "#{period} days ago UTC"
                    else "#{period} hours ago UTC"
                    end
        
        chart_data = get_historical_data(cryptocurrency.symbol, interval, start_time)
        next if chart_data.empty?
        
        # Speichere die Daten in der Datenbank
        chart_data.each do |data|
          next unless data[:close] && data[:close] > 0
          
          # Berechne RSI, ROC und ROC' für diesen Datenpunkt
          rsi = data[:rsi_1h] || calculate_rsi_for_timestamp(cryptocurrency.symbol, data[:timestamp], interval)
          roc = data[:roc_1h] || calculate_roc_for_timestamp(cryptocurrency.symbol, data[:timestamp], interval)
          roc_derivative = data[:roc_derivative_1h] || calculate_roc_derivative_for_timestamp(cryptocurrency.symbol, data[:timestamp], interval)
          
          # Erstelle historischen Datensatz
          CryptoHistoryData.record_data(cryptocurrency, {
            timestamp: Time.at(data[:timestamp] / 1000),
            open: data[:open],
            high: data[:high],
            low: data[:low],
            close: data[:close],
            volume: data[:volume],
            rsi: rsi,
            roc: roc,
            roc_derivative: roc_derivative
          }, interval)
        end
        
        puts "Stored #{chart_data.length} historical records for #{cryptocurrency.symbol} (#{interval})"
        
        # Kleine Pause um Rate Limits zu vermeiden
        sleep(0.2)
        
      rescue => e
        puts "Error storing historical data for #{cryptocurrency.symbol} (#{interval}): #{e.message}"
        next
      end
    end
    
    # Cleanup alte Daten basierend auf der Periode
    CryptoHistoryData.cleanup_old_data(period)
  end
  
  def self.calculate_rsi_for_timestamp(symbol, timestamp, interval)
    # Berechne RSI für einen spezifischen Timestamp
    # Diese Methode würde die RSI-Berechnung für einen einzelnen Datenpunkt implementieren
    # Vereinfachte Implementierung - in der Praxis würde man mehr historische Daten benötigen
    nil
  end
  
  def self.calculate_roc_for_timestamp(symbol, timestamp, interval)
    # Berechne ROC für einen spezifischen Timestamp
    nil
  end
  
  def self.calculate_roc_derivative_for_timestamp(symbol, timestamp, interval)
    # Berechne ROC-Ableitung für einen spezifischen Timestamp
    nil
  end

  def self.find_or_create_cryptocurrency(name, symbol, price, rsi, volume_24h = 0)
    # Market Cap berechnen basierend auf geschätzter Coin Supply
    estimated_supply = estimate_coin_supply(name.upcase)
    market_cap_usd = price * estimated_supply

    # ROC und ROC-Ableitung berechnen
    roc = calculate_roc_for_symbol(symbol, '1h')
    roc_derivative = calculate_roc_derivative_for_symbol(symbol, '1h')

    # Verwende das vollständige Trading-Pair als Symbol
    crypto = Cryptocurrency.find_or_initialize_by(symbol: symbol.upcase)
    
    crypto.assign_attributes(
      name: format_crypto_name(name),
      symbol: symbol.upcase, # Vollständiges Trading-Pair (z.B. BTCUSDC)
      current_price: price,
      market_cap: market_cap_usd,
      rsi: rsi,
      roc: roc,
      roc_derivative: roc_derivative,
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

  def self.interpolate_rsi_value(target_timestamp, rsi_map, timeframe)
    return nil if rsi_map.empty?
    
    # Filtere nur gültige RSI-Werte (nicht null/nil)
    valid_rsi_map = rsi_map.select { |timestamp, rsi| rsi && rsi.is_a?(Numeric) && !rsi.nan? }
    
    if valid_rsi_map.empty?
      puts "1m interpolation: No valid RSI values found in map"
      return nil
    end
    
    # Finde den zeitlich nächstgelegenen Zeitstempel mit gültigem RSI-Wert
    closest_timestamp = valid_rsi_map.keys.min_by { |ts| (ts - target_timestamp).abs }
    time_diff = (closest_timestamp - target_timestamp).abs
    rsi_value = valid_rsi_map[closest_timestamp]
    
    puts "1m interpolation: target=#{Time.at(target_timestamp/1000)}, closest=#{Time.at(closest_timestamp/1000)}, diff=#{time_diff/1000}s, rsi=#{rsi_value}"
    
    # Gib den gültigen RSI-Wert zurück
    rsi_value
  end

  # Neue Methode: Hole ROC-Daten für mehrere Zeitrahmen (1m, 15m, 1h)
  def self.get_multi_timeframe_roc_for_chart_data(symbol, chart_data)
    puts "Fetching multi-timeframe ROC data for #{symbol} (15m, 1h)"
    
    roc_data = {}
    timeframes = ['15m', '1h']
    
    timeframes.each do |timeframe|
      puts "Fetching #{timeframe} ROC data for #{symbol}"
      
      # Bestimme wie viele Tage zurück wir gehen müssen
      days_back = case timeframe
                  when '15m' then 7  # 7 Tage für 15m
                  when '1h' then 30  # 30 Tage für 1h
                  end
      
      start_time_tf = (Time.current - days_back.days).to_i * 1000
      
      response = get("/api/v3/klines", query: {
        symbol: symbol,
        interval: timeframe,
        startTime: start_time_tf,
        limit: 1000
      })

      if response.success?
        klines_tf = response.parsed_response
        puts "Received #{klines_tf.length} #{timeframe} klines for ROC calculation"
        
        # Berechne ROC für diesen Zeitrahmen
        closes_tf = klines_tf.map { |kline| kline[4].to_f }
        roc_tf_values = calculate_historical_roc(closes_tf)
        
        # Erstelle Mapping von Zeitstempel zu ROC-Werten
        roc_map_tf = {}
        klines_tf.each_with_index do |kline, index|
          timestamp_tf = kline[0]
          roc_map_tf[timestamp_tf] = roc_tf_values[index]
        end
        
        # Mappe ROC-Werte auf Chart-Datenpunkte
        roc_data[timeframe] = chart_data.map do |data_point|
          chart_timestamp = data_point[:timestamp]
          
          # Für 1m-Daten: Verwende Interpolation wenn nötig
          if timeframe == '1m'
            roc_value = interpolate_roc_value(chart_timestamp, roc_map_tf, timeframe)
          else
            # Für 15m und 1h: Normale Zuordnung
            closest_timestamp = find_closest_timestamp_for_timeframe(chart_timestamp, roc_map_tf.keys, timeframe)
            roc_value = roc_map_tf[closest_timestamp]
          end
          
          roc_value
        end
      else
        puts "Error fetching #{timeframe} data for ROC: #{response.code}"
        roc_data[timeframe] = chart_data.map { |data| nil }
      end
    end
    
    roc_data
  rescue => e
    puts "Exception in get_multi_timeframe_roc_for_chart_data: #{e.message}"
    { '1m' => chart_data.map { |data| nil }, '15m' => chart_data.map { |data| nil }, '1h' => chart_data.map { |data| nil } }
  end

  # Neue Methode: Hole ROC-Ableitungs-Daten für mehrere Zeitrahmen (1m, 15m, 1h)
  def self.get_multi_timeframe_roc_derivative_for_chart_data(symbol, chart_data)
    puts "Fetching multi-timeframe ROC derivative data for #{symbol} (15m, 1h)"
    
    roc_derivative_data = {}
    timeframes = ['15m', '1h']
    
    timeframes.each do |timeframe|
      puts "Fetching #{timeframe} ROC derivative data for #{symbol}"
      
      # Bestimme wie viele Tage zurück wir gehen müssen
      days_back = case timeframe
                  when '15m' then 7  # 7 Tage für 15m
                  when '1h' then 30  # 30 Tage für 1h
                  end
      
      start_time_tf = (Time.current - days_back.days).to_i * 1000
      
      response = get("/api/v3/klines", query: {
        symbol: symbol,
        interval: timeframe,
        startTime: start_time_tf,
        limit: 1000
      })

      if response.success?
        klines_tf = response.parsed_response
        puts "Received #{klines_tf.length} #{timeframe} klines for ROC derivative calculation"
        
        # Berechne ROC-Ableitung für diesen Zeitrahmen
        closes_tf = klines_tf.map { |kline| kline[4].to_f }
        roc_derivative_tf_values = calculate_historical_roc_derivative(closes_tf)
        
        # Erstelle Mapping von Zeitstempel zu ROC-Ableitungs-Werten
        roc_derivative_map_tf = {}
        klines_tf.each_with_index do |kline, index|
          timestamp_tf = kline[0]
          roc_derivative_map_tf[timestamp_tf] = roc_derivative_tf_values[index]
        end
        
        # Mappe ROC-Ableitungs-Werte auf Chart-Datenpunkte
        roc_derivative_data[timeframe] = chart_data.map do |data_point|
          chart_timestamp = data_point[:timestamp]
          
          # Für 1m-Daten: Verwende Interpolation wenn nötig
          if timeframe == '1m'
            roc_derivative_value = interpolate_roc_derivative_value(chart_timestamp, roc_derivative_map_tf, timeframe)
          else
            # Für 15m und 1h: Normale Zuordnung
            closest_timestamp = find_closest_timestamp_for_timeframe(chart_timestamp, roc_derivative_map_tf.keys, timeframe)
            roc_derivative_value = roc_derivative_map_tf[closest_timestamp]
          end
          
          roc_derivative_value
        end
      else
        puts "Error fetching #{timeframe} data for ROC derivative: #{response.code}"
        roc_derivative_data[timeframe] = chart_data.map { |data| nil }
      end
    end
    
    roc_derivative_data
  rescue => e
    puts "Exception in get_multi_timeframe_roc_derivative_for_chart_data: #{e.message}"
    { '1m' => chart_data.map { |data| nil }, '15m' => chart_data.map { |data| nil }, '1h' => chart_data.map { |data| nil } }
  end

  # Hilfsmethode: Berechne historische ROC-Werte
  def self.calculate_historical_roc(closes, period = ROC_PERIOD)
    return [] if closes.length < period + 1
    
    roc_values = []
    
    # Für die ersten period-1 Werte gibt es keinen ROC
    (period - 1).times { roc_values << nil }
    
    # Berechne ROC für jeden möglichen Punkt
    (period - 1...closes.length).each do |i|
      subset = closes[0..i]
      next if subset.length < period + 1
      
      roc = calculate_roc(subset, period)
      roc_values << roc
    end
    
    roc_values
  end

  # Hilfsmethode: Berechne historische ROC-Ableitungs-Werte
  def self.calculate_historical_roc_derivative(closes, period = ROC_PERIOD)
    return [] if closes.length < period + 2
    
    roc_derivative_values = []
    
    # Für die ersten period-1 Werte gibt es keine ROC-Ableitung
    (period - 1).times { roc_derivative_values << nil }
    
    # Berechne ROC-Ableitung für jeden möglichen Punkt
    (period - 1...closes.length).each do |i|
      subset = closes[0..i]
      next if subset.length < period + 2
      
      roc_derivative = calculate_roc_derivative(subset, period)
      roc_derivative_values << roc_derivative
    end
    
    roc_derivative_values
  end

  # Hilfsmethode: Interpoliere ROC-Werte
  def self.interpolate_roc_value(target_timestamp, roc_map, timeframe)
    return nil if roc_map.empty?
    
    # Filtere nur gültige ROC-Werte (nicht null/nil)
    valid_roc_map = roc_map.select { |timestamp, roc| roc && roc.is_a?(Numeric) && !roc.nan? }
    
    if valid_roc_map.empty?
      puts "1m ROC interpolation: No valid ROC values found in map"
      return nil
    end
    
    # Finde den zeitlich nächstgelegenen Zeitstempel mit gültigem ROC-Wert
    closest_timestamp = valid_roc_map.keys.min_by { |ts| (ts - target_timestamp).abs }
    roc_value = valid_roc_map[closest_timestamp]
    
    roc_value
  end

  # Hilfsmethode: Interpoliere ROC-Ableitungs-Werte
  def self.interpolate_roc_derivative_value(target_timestamp, roc_derivative_map, timeframe)
    return nil if roc_derivative_map.empty?
    
    # Filtere nur gültige ROC-Ableitungs-Werte (nicht null/nil)
    valid_roc_derivative_map = roc_derivative_map.select { |timestamp, roc_derivative| roc_derivative && roc_derivative.is_a?(Numeric) && !roc_derivative.nan? }
    
    if valid_roc_derivative_map.empty?
      puts "1m ROC derivative interpolation: No valid ROC derivative values found in map"
      return nil
    end
    
    # Finde den zeitlich nächstgelegenen Zeitstempel mit gültigem ROC-Ableitungs-Wert
    closest_timestamp = valid_roc_derivative_map.keys.min_by { |ts| (ts - target_timestamp).abs }
    roc_derivative_value = valid_roc_derivative_map[closest_timestamp]
    
    roc_derivative_value
  end
end 