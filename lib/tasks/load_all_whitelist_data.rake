require 'net/http'
require 'json'

namespace :crypto do
  desc "Lade historische Daten für alle Pairs aus bot.json (letzte 2 Tage)"
  task load_all_whitelist_data: :environment do
    puts "🚀 Lade historische Daten für alle Whitelist-Pairs..."
    
    # Lade Whitelist aus bot.json
    whitelist = load_whitelist_pairs
    if whitelist.empty?
      puts "❌ Keine Pairs in bot.json gefunden"
      exit 1
    end
    
    puts "📋 Gefundene Pairs: #{whitelist.join(', ')}"
    puts "📅 Zeitrahmen: Letzte 2 Tage"
    
    # Zeitrahmen definieren
    end_time = Time.now
    start_time = end_time - 2.days
    
    # Verschiedene Timeframes
    timeframes = ['1m', '5m', '15m', '1h', '4h']
    
    whitelist.each_with_index do |pair, index|
      puts "\n" + "="*60
      puts "📊 Bearbeite Pair #{index + 1}/#{whitelist.length}: #{pair}"
      puts "="*60
      
      # Konvertiere Pair-Format für Binance API (BTC/USDC -> BTCUSDC)
      binance_symbol = pair.gsub('/', '')
      
      begin
        # Erstelle oder finde Kryptowährung
        crypto = Cryptocurrency.find_or_create_by(symbol: pair) do |c|
          base_symbol = pair.split('/').first
          c.name = get_crypto_name(base_symbol)
          c.current_price = 1.0
          c.market_cap = 1000000
          c.market_cap_rank = 9999
        end
        
        puts "🪙 Kryptowährung: #{crypto.name} (#{crypto.symbol})"
        
        # Lade Daten für jeden Timeframe
        timeframes.each do |interval|
          puts "\n📈 Lade #{interval} Daten für #{binance_symbol}..."
          
          begin
            # Hole historische Daten von Binance API
            klines = fetch_binance_klines(binance_symbol, interval, start_time, end_time)
            
            if klines.empty?
              puts "[!] Keine #{interval} Daten für #{binance_symbol} gefunden"
              next
            end
            
            puts "📊 #{klines.length} #{interval} Kerzen von Binance erhalten"
            
            # Speichere historische Daten
            saved_count = 0
            skipped_count = 0
            
            klines.each do |kline|
              timestamp = Time.at(kline[0] / 1000)
              
              # Prüfe ob Datensatz bereits existiert
              existing = CryptoHistoryData.find_by(
                cryptocurrency: crypto,
                timestamp: timestamp,
                interval: interval
              )
              
              if existing
                skipped_count += 1
                next
              end
              
              # Erstelle neuen Datensatz
              CryptoHistoryData.create!(
                cryptocurrency: crypto,
                timestamp: timestamp,
                open_price: kline[1].to_f,
                high_price: kline[2].to_f,
                low_price: kline[3].to_f,
                close_price: kline[4].to_f,
                volume: kline[5].to_f,
                interval: interval
              )
              
              saved_count += 1
            end
            
            puts "✅ #{saved_count} neue #{interval} Datensätze gespeichert"
            puts "⏭️ #{skipped_count} bereits vorhandene Datensätze übersprungen" if skipped_count > 0
            
            # Aktualisiere aktuellen Preis mit dem letzten verfügbaren
            if klines.any?
              latest_price = klines.last[4].to_f
              crypto.update!(current_price: latest_price)
              puts "💰 Aktueller Preis aktualisiert: $#{latest_price}"
            end
            
          rescue => e
            puts "❌ Fehler beim Laden der #{interval} Daten für #{binance_symbol}: #{e.message}"
          end
          
          # Kurze Pause zwischen API-Aufrufen
          sleep(0.2)
        end
        
        # Berechne RSI für alle Timeframes
        puts "\n📊 Berechne RSI für #{pair}..."
        calculate_rsi_for_all_timeframes(crypto)
        
        puts "✅ #{pair} erfolgreich verarbeitet!"
        
      rescue => e
        puts "❌ Fehler beim Verarbeiten von #{pair}: #{e.message}"
      end
      
      # Pause zwischen verschiedenen Pairs
      sleep(1) if index < whitelist.length - 1
    end
    
    # Abschluss-Statistiken
    puts "\n" + "="*60
    puts "🎉 Alle Whitelist-Pairs erfolgreich geladen!"
    puts "="*60
    
    whitelist.each do |pair|
      crypto = Cryptocurrency.find_by(symbol: pair)
      next unless crypto
      
      total_data = CryptoHistoryData.where(cryptocurrency: crypto).count
      indicator_data = Indicator.where(cryptocurrency: crypto).count
      
      puts "📊 #{pair}:"
      puts "   Historische Datensätze: #{total_data}"
      puts "   Indikator-Datensätze: #{indicator_data}"
      puts "   Aktueller Preis: $#{crypto.current_price}"
      puts "   Aktueller RSI: #{crypto.rsi || 'N/A'}"
    end
    
    puts "\n🚀 Bereit für Live-Trading!"
  end
  
  private
  
  def self.load_whitelist_pairs
    config_path = Rails.root.join('config', 'bot.json')
    return [] unless File.exist?(config_path)
    
    begin
      config = JSON.parse(File.read(config_path))
      config.dig('exchange', 'pair_whitelist') || []
    rescue => e
      puts "❌ Fehler beim Laden der bot.json: #{e.message}"
      []
    end
  end
  
  def self.fetch_binance_klines(symbol, interval, start_time, end_time)
    # Binance API: Kline/Candlestick Daten
    uri = URI("https://api.binance.com/api/v3/klines")
    params = {
      'symbol' => symbol,
      'interval' => interval,
      'startTime' => (start_time.to_f * 1000).to_i,
      'endTime' => (end_time.to_f * 1000).to_i,
      'limit' => 1000
    }
    
    uri.query = URI.encode_www_form(params)
    
    puts "[->] API-Aufruf: #{uri}"
    
    response = Net::HTTP.get_response(uri)
    
    unless response.is_a?(Net::HTTPSuccess)
      puts "❌ API-Fehler: #{response.code} - #{response.message}"
      return []
    end
    
    klines = JSON.parse(response.body)
    klines
  rescue => e
    puts "❌ Fehler beim API-Aufruf: #{e.message}"
    []
  end
  
  def self.get_crypto_name(base_symbol)
    # Mapping von Symbolen zu echten Namen
    name_mapping = {
      'BTC' => 'Bitcoin',
      'ETH' => 'Ethereum',
      'BNB' => 'Binance Coin',
      'ADA' => 'Cardano',
      'SOL' => 'Solana',
      'NEWT' => 'Newton Project'
    }
    
    name_mapping[base_symbol] || base_symbol
  end
  
  def self.calculate_rsi_for_all_timeframes(cryptocurrency)
    timeframes = ['1m', '5m', '15m', '1h', '4h']
    period = 14
    
    timeframes.each do |timeframe|
      puts "📊 Berechne RSI für #{timeframe}..."
      
      begin
        rsi_value = IndicatorCalculationService.calculate_and_save_rsi(
          cryptocurrency, 
          timeframe, 
          period
        )
        
        if rsi_value
          puts "✅ RSI #{timeframe}: #{rsi_value}"
        else
          puts "[!] RSI-Berechnung für #{timeframe} fehlgeschlagen (nicht genug Daten)"
        end
      rescue => e
        puts "❌ Fehler bei RSI-Berechnung für #{timeframe}: #{e.message}"
      end
    end
  end
end 