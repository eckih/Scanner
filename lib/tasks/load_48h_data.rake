require 'net/http'
require 'json'

namespace :crypto do
  desc "Lade historische Daten für alle Pairs aus bot.json (letzte 48 Stunden)"
  task load_48h_data: :environment do
    puts "🚀 Lade historische Daten für alle Whitelist-Pairs (48h)..."
    
    # Lade Whitelist aus bot.json
    whitelist = load_whitelist_pairs
    if whitelist.empty?
      puts "❌ Keine Pairs in bot.json gefunden"
      exit 1
    end
    
    puts "📋 Gefundene Pairs: #{whitelist.join(', ')}"
    puts "📅 Zeitrahmen: Letzte 48 Stunden"
    
    # Zeitrahmen definieren
    end_time = Time.now
    start_time = end_time - 48.hours
    
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
          c.name = pair.split('/').first
        end
        
        timeframes.each do |timeframe|
          puts "  ⏰ Timeframe: #{timeframe}"
          
          # Berechne Limit basierend auf Timeframe (48h)
          limit = case timeframe
                  when '1m' then 2880  # 48 * 60 Minuten
                  when '5m' then 576   # 48 * 12 (5-Minuten-Intervalle pro Stunde)
                  when '15m' then 192  # 48 * 4 (15-Minuten-Intervalle pro Stunde)
                  when '1h' then 48    # 48 Stunden
                  when '4h' then 12    # 48 / 4 Stunden
                  else 48
                  end
          
          # Binance API URL
          url = "https://api.binance.com/api/v3/klines?symbol=#{binance_symbol}&interval=#{timeframe}&limit=#{limit}"
          
          begin
            uri = URI(url)
            response = Net::HTTP.get_response(uri)
            
            if response.is_a?(Net::HTTPSuccess)
              data = JSON.parse(response.body)
              
              puts "    📥 #{data.length} Datensätze erhalten"
              
              # Speichere Daten in der Datenbank
              saved_count = 0
              data.each do |kline|
                timestamp = Time.at(kline[0] / 1000.0)
                
                # Prüfe, ob der Datensatz bereits existiert
                existing = CryptoHistoryData.find_by(
                  cryptocurrency: crypto,
                  timestamp: timestamp,
                  interval: timeframe
                )
                
                unless existing
                  CryptoHistoryData.create!(
                    cryptocurrency: crypto,
                    timestamp: timestamp,
                    open_price: kline[1].to_f,
                    high_price: kline[2].to_f,
                    low_price: kline[3].to_f,
                    close_price: kline[4].to_f,
                    volume: kline[5].to_f,
                    interval: timeframe
                  )
                  saved_count += 1
                end
              end
              
              puts "    💾 #{saved_count} neue Datensätze für #{timeframe} gespeichert"
            else
              puts "    ❌ API-Fehler: #{response.code} - #{response.message}"
            end
            
          rescue => e
            puts "    ❌ Fehler beim Laden von #{pair} #{timeframe}: #{e.message}"
          end
          
          # Rate Limiting
          sleep(0.1)
        end
        
        # Längere Pause zwischen Pairs
        sleep(0.5)
        
      rescue => e
        puts "❌ Fehler beim Verarbeiten von #{pair}: #{e.message}"
      end
    end
    
    puts "\n✅ 48h historische Daten erfolgreich geladen!"
    puts "📊 Datenbankstatistik:"
    
    timeframes.each do |interval|
      count = CryptoHistoryData.where(interval: interval).count
      puts "  #{interval}: #{count} Einträge"
    end
  end
end

# Hilfsfunktion zum Laden der Whitelist
def load_whitelist_pairs
  config_path = File.join(Rails.root, 'config', 'bot.json')
  return [] unless File.exist?(config_path)
  
  begin
    config = JSON.parse(File.read(config_path))
    config.dig('exchange', 'pair_whitelist') || []
  rescue => e
    puts "❌ Fehler beim Laden der bot.json: #{e.message}"
    []
  end
end