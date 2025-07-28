require 'net/http'
require 'json'

namespace :crypto do
  desc "Lade NEWT/USDT Kursdaten der letzten 2 Tage"
  task load_newt_data: :environment do
    puts "🪙 Lade NEWT/USDT Kursdaten der letzten 2 Tage..."
    
    # NEWT/USDT Symbol für Binance API
    symbol = "NEWTUSDT"
    
    # Zeitrahmen: Letzte 2 Tage
    end_time = Time.now
    start_time = end_time - 2.days
    
    puts "📅 Zeitrahmen: #{start_time.strftime('%Y-%m-%d %H:%M')} bis #{end_time.strftime('%Y-%m-%d %H:%M')}"
    
    # Verschiedene Timeframes für historische Daten
    timeframes = ['1m', '5m', '15m', '1h', '4h']
    
    timeframes.each do |interval|
      puts "\n📊 Lade #{interval} Daten für #{symbol}..."
      
      begin
        # Hole historische Daten von Binance API
        klines = fetch_binance_klines(symbol, interval, start_time, end_time)
        
        if klines.empty?
          puts "⚠️ Keine #{interval} Daten für #{symbol} gefunden"
          next
        end
        
        puts "📈 #{klines.length} #{interval} Kerzen gefunden"
        
        # Erstelle oder finde NEWT/USDT Kryptowährung
        crypto = Cryptocurrency.find_or_create_by(symbol: "NEWT/USDT") do |c|
          c.name = "Newton Project"
          c.current_price = 1.0
          c.market_cap = 1000000
          c.market_cap_rank = 9999
        end
        
        # Speichere historische Daten
        saved_count = 0
        klines.each do |kline|
          timestamp = Time.at(kline[0] / 1000)
          
          # Prüfe ob Datensatz bereits existiert
          existing = CryptoHistoryData.find_by(
            cryptocurrency: crypto,
            timestamp: timestamp,
            interval: interval
          )
          
          next if existing
          
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
        
        # Aktualisiere aktuellen Preis mit dem letzten verfügbaren
        if klines.any?
          latest_price = klines.last[4].to_f
          crypto.update!(current_price: latest_price)
          puts "💰 Aktueller Preis aktualisiert: $#{latest_price}"
        end
        
      rescue => e
        puts "❌ Fehler beim Laden der #{interval} Daten: #{e.message}"
      end
      
      # Kurze Pause zwischen API-Aufrufen
      sleep(0.5)
    end
    
    # Berechne RSI für alle Timeframes
    puts "\n📊 Berechne RSI für NEWT/USDT..."
    calculate_rsi_for_cryptocurrency(crypto)
    
    puts "\n🎉 NEWT/USDT Daten erfolgreich geladen!"
    puts "📊 Datenbankstatistik für NEWT/USDT:"
    puts "  Historische Datensätze: #{CryptoHistoryData.where(cryptocurrency: crypto).count}"
    puts "  Indikator-Datensätze: #{Indicator.where(cryptocurrency: crypto).count}"
    puts "  Aktueller Preis: $#{crypto.current_price}"
  end
  
  private
  
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
    
    puts "🔗 API-Aufruf: #{uri}"
    
    response = Net::HTTP.get_response(uri)
    
    unless response.is_a?(Net::HTTPSuccess)
      puts "❌ API-Fehler: #{response.code} - #{response.message}"
      return []
    end
    
    klines = JSON.parse(response.body)
    puts "📊 #{klines.length} Kerzen von Binance erhalten"
    
    klines
  rescue => e
    puts "❌ Fehler beim API-Aufruf: #{e.message}"
    []
  end
  
  def self.calculate_rsi_for_cryptocurrency(cryptocurrency)
    # Berechne RSI für verschiedene Timeframes
    timeframes = ['1m', '5m', '15m', '1h', '4h']
    period = 14
    
    timeframes.each do |timeframe|
      puts "📊 Berechne RSI für #{timeframe}..."
      
      # Hole historische Daten für RSI-Berechnung
      historical_data = CryptoHistoryData.where(
        cryptocurrency: cryptocurrency,
        interval: timeframe
      ).order(:timestamp).limit(period + 10) # Extra Daten für bessere Berechnung
      
      if historical_data.count < period
        puts "⚠️ Nicht genug Daten für #{timeframe} RSI (benötigt: #{period}, vorhanden: #{historical_data.count})"
        next
      end
      
      # Berechne RSI
      prices = historical_data.pluck(:close_price)
      rsi_value = calculate_rsi(prices, period)
      
      if rsi_value
        # Speichere RSI-Wert mit neuem IndicatorCalculationService
        IndicatorCalculationService.calculate_and_save_rsi(cryptocurrency, timeframe, period)
        
        puts "✅ RSI #{timeframe}: #{rsi_value.round(2)}"
      else
        puts "⚠️ RSI-Berechnung für #{timeframe} fehlgeschlagen"
      end
    end
  end
  
  def self.calculate_rsi(prices, period)
    return nil if prices.length < period + 1
    
    gains = []
    losses = []
    
    # Berechne Gewinne und Verluste
    (1...prices.length).each do |i|
      change = prices[i] - prices[i-1]
      if change > 0
        gains << change
        losses << 0
      else
        gains << 0
        losses << change.abs
      end
    end
    
    # Berechne durchschnittliche Gewinne und Verluste
    avg_gain = gains.last(period).sum.to_f / period
    avg_loss = losses.last(period).sum.to_f / period
    
    return nil if avg_loss == 0
    
    # Berechne RSI
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    rsi
  end
end 