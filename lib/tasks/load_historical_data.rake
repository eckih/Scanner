require 'net/http'
require 'json'

namespace :crypto do
  desc "Lade historische Kursdaten der letzten 2 Tage von Binance API"
  task load_historical_data: :environment do
    puts "🚀 Starte das Laden historischer Kursdaten..."
    
    # Timeframes für die wir Daten laden wollen
    timeframes = {
      '1m' => '1m',
      '5m' => '5m', 
      '15m' => '15m',
      '1h' => '1h',
      '4h' => '4h',
      '1d' => '1d'
    }
    
    # Hole alle Kryptowährungen aus der Datenbank
    cryptocurrencies = Cryptocurrency.all
    puts "📊 Lade Daten für #{cryptocurrencies.count} Kryptowährungen..."
    
    cryptocurrencies.each do |crypto|
      puts "\n📈 Verarbeite #{crypto.symbol}..."
      
      timeframes.each do |interval, binance_interval|
        puts "  ⏰ Timeframe: #{interval}"
        
        begin
          # Berechne Start- und Endzeit (letzte 2 Tage)
          end_time = Time.now.to_i * 1000
          start_time = (Time.now - 2.days).to_i * 1000
          
          # Binance API URL
          symbol = crypto.symbol.gsub('USDC', 'USDT') # Binance verwendet meist USDT
          url = "https://api.binance.com/api/v3/klines?symbol=#{symbol}&interval=#{binance_interval}&startTime=#{start_time}&endTime=#{end_time}&limit=1000"
          
          puts "    🌐 API-Aufruf: #{url}"
          
          # API-Aufruf
          uri = URI(url)
          response = Net::HTTP.get_response(uri)
          
          if response.code == '200'
            klines = JSON.parse(response.body)
            puts "    ✅ #{klines.length} Kerzen erhalten"
            
            # Verarbeite jede Kerze
            klines.each do |kline|
              timestamp = Time.at(kline[0] / 1000)
              open_price = kline[1].to_f
              high_price = kline[2].to_f
              low_price = kline[3].to_f
              close_price = kline[4].to_f
              volume = kline[5].to_f
              
              # Prüfe ob bereits vorhanden
              existing = CryptoHistoryData.find_by(
                cryptocurrency: crypto,
                timestamp: timestamp,
                interval: interval
              )
              
              unless existing
                CryptoHistoryData.create!(
                  cryptocurrency: crypto,
                  timestamp: timestamp,
                  open_price: open_price,
                  high_price: high_price,
                  low_price: low_price,
                  close_price: close_price,
                  volume: volume,
                  interval: interval
                )
              end
            end
            
            puts "    💾 Daten für #{interval} gespeichert"
            
          else
            puts "    ❌ API-Fehler: #{response.code} - #{response.body}"
            
            # Fallback: Versuche mit USDC statt USDT
            if symbol.include?('USDT')
              symbol_usdc = symbol.gsub('USDT', 'USDC')
              url_usdc = "https://api.binance.com/api/v3/klines?symbol=#{symbol_usdc}&interval=#{binance_interval}&startTime=#{start_time}&endTime=#{end_time}&limit=1000"
              
              puts "    🔄 Versuche mit USDC: #{url_usdc}"
              
              uri_usdc = URI(url_usdc)
              response_usdc = Net::HTTP.get_response(uri_usdc)
              
              if response_usdc.code == '200'
                klines = JSON.parse(response_usdc.body)
                puts "    ✅ #{klines.length} Kerzen mit USDC erhalten"
                
                klines.each do |kline|
                  timestamp = Time.at(kline[0] / 1000)
                  open_price = kline[1].to_f
                  high_price = kline[2].to_f
                  low_price = kline[3].to_f
                  close_price = kline[4].to_f
                  volume = kline[5].to_f
                  
                  existing = CryptoHistoryData.find_by(
                    cryptocurrency: crypto,
                    timestamp: timestamp,
                    interval: interval
                  )
                  
                  unless existing
                    CryptoHistoryData.create!(
                      cryptocurrency: crypto,
                      timestamp: timestamp,
                      open_price: open_price,
                      high_price: high_price,
                      low_price: low_price,
                      close_price: close_price,
                      volume: volume,
                      interval: interval
                    )
                  end
                end
                
                puts "    💾 Daten für #{interval} mit USDC gespeichert"
              else
                puts "    ❌ Auch USDC fehlgeschlagen: #{response_usdc.code}"
              end
            end
          end
          
          # Rate Limiting - kurze Pause zwischen API-Aufrufen
          sleep(0.1)
          
        rescue => e
          puts "    ❌ Fehler beim Laden von #{crypto.symbol} #{interval}: #{e.message}"
        end
      end
      
      # Längere Pause zwischen Kryptowährungen
      sleep(0.5)
    end
    
    puts "\n✅ Historische Daten erfolgreich geladen!"
    puts "📊 Datenbankstatistik:"
    
    timeframes.each_key do |interval|
      count = CryptoHistoryData.where(interval: interval).count
      puts "  #{interval}: #{count} Einträge"
    end
  end
  
  desc "Berechne RSI für alle Timeframes nach dem Laden historischer Daten"
  task calculate_rsi_all_timeframes: :environment do
    puts "🚀 Starte RSI-Berechnung für alle Timeframes..."
    
    timeframes = ['1m', '5m', '15m', '1h', '4h', '1d']
    
    timeframes.each do |timeframe|
      puts "\n📊 Berechne RSI für Timeframe: #{timeframe}"
      
      begin
        # Verwende den neuen IndicatorCalculationService für alle Kryptowährungen
        Cryptocurrency.find_each do |crypto|
          IndicatorCalculationService.calculate_and_save_rsi(crypto, timeframe, 14)
        end
        puts "✅ RSI-Berechnung für #{timeframe} abgeschlossen"
      rescue => e
        puts "❌ Fehler bei RSI-Berechnung für #{timeframe}: #{e.message}"
      end
      
      # Kurze Pause zwischen Timeframes
      sleep(1)
    end
    
    puts "\n✅ RSI-Berechnung für alle Timeframes abgeschlossen!"
  end
  
  desc "Lade historische Daten und berechne RSI (Komplett-Task)"
  task setup_historical_data: :environment do
    puts "🚀 Starte komplette historische Dateneinrichtung..."
    
    # Erst historische Daten laden
    Rake::Task['crypto:load_historical_data'].invoke
    
    puts "\n⏳ Warte 5 Sekunden vor RSI-Berechnung..."
    sleep(5)
    
    # Dann RSI für alle Timeframes berechnen
    Rake::Task['crypto:calculate_rsi_all_timeframes'].invoke
    
    puts "\n🎉 Komplette historische Dateneinrichtung abgeschlossen!"
  end
end 