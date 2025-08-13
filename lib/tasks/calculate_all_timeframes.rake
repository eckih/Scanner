require 'net/http'
require 'json'

namespace :crypto do
  desc "Berechne alle Zeitrahmen (24h, 1h, 30min) für alle Kryptowährungen"
  task calculate_all_timeframes: :environment do
    puts "📊 Berechne alle Zeitrahmen für alle Kryptowährungen..."
    
    cryptocurrencies = Cryptocurrency.all
    puts "📈 Berechne für #{cryptocurrencies.count} Kryptowährungen..."
    
    updated_count = 0
    error_count = 0
    
    cryptocurrencies.each do |crypto|
      begin
        puts "\n💰 Berechne Zeitrahmen für #{crypto.symbol}..."
        
        # Hole aktuellen Preis
        current_price = crypto.current_price || 0
        
        if current_price > 0
          # Berechne 24h Änderung
          twenty_four_hours_ago = Time.now - 24.hours
          historical_data_24h = CryptoHistoryData.where(
            cryptocurrency: crypto,
            timestamp: ..twenty_four_hours_ago,
            interval: '1m'
          ).order(:timestamp).last
          
          # Berechne 1h Änderung
          one_hour_ago = Time.now - 1.hour
          historical_data_1h = CryptoHistoryData.where(
            cryptocurrency: crypto,
            timestamp: ..one_hour_ago,
            interval: '1m'
          ).order(:timestamp).last
          
          # Berechne 30min Änderung
          thirty_minutes_ago = Time.now - 30.minutes
          historical_data_30min = CryptoHistoryData.where(
            cryptocurrency: crypto,
            timestamp: ..thirty_minutes_ago,
            interval: '1m'
          ).order(:timestamp).last
          
          # 24h Änderung
          if historical_data_24h
            old_price_24h = historical_data_24h.close_price
            price_change_24h = ((current_price - old_price_24h) / old_price_24h) * 100
            is_24h_complete = true
            puts "   24h: #{price_change_24h.round(2)}% (von #{old_price_24h})"
          else
            price_change_24h = 0.0
            is_24h_complete = false
            puts "   24h: Keine Daten"
          end
          
          # 1h Änderung
          if historical_data_1h
            old_price_1h = historical_data_1h.close_price
            price_change_1h = ((current_price - old_price_1h) / old_price_1h) * 100
            is_1h_complete = true
            puts "   1h:  #{price_change_1h.round(2)}% (von #{old_price_1h})"
          else
            price_change_1h = 0.0
            is_1h_complete = false
            puts "   1h:  Keine Daten"
          end
          
          # 30min Änderung
          if historical_data_30min
            old_price_30min = historical_data_30min.close_price
            price_change_30min = ((current_price - old_price_30min) / old_price_30min) * 100
            is_30min_complete = true
            puts "   30min: #{price_change_30min.round(2)}% (von #{old_price_30min})"
          else
            price_change_30min = 0.0
            is_30min_complete = false
            puts "   30min: Keine Daten"
          end
          
          # Aktualisiere alle Änderungen
          crypto.update!(
            price_change_percentage_24h: price_change_24h.round(2),
            price_change_24h_complete: is_24h_complete,
            price_change_percentage_1h: price_change_1h.round(2),
            price_change_1h_complete: is_1h_complete,
            price_change_percentage_30min: price_change_30min.round(2),
            price_change_30min_complete: is_30min_complete,
            last_updated: Time.current
          )
          
          puts "✅ #{crypto.symbol} aktualisiert"
          updated_count += 1
        else
          puts "❌ #{crypto.symbol}: Kein aktueller Preis verfügbar"
          error_count += 1
        end
        
      rescue => e
        puts "❌ Fehler bei #{crypto.symbol}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\n🎉 Berechnung abgeschlossen!"
    puts "📊 Statistik:"
    puts "  Erfolgreich berechnet: #{updated_count}"
    puts "  Fehler: #{error_count}"
    puts "  Gesamt: #{cryptocurrencies.count}"
    
    if updated_count > 0
      puts "\n📈 Beispiel-Ergebnisse:"
      cryptocurrencies.reload.limit(5).each do |crypto|
        puts "  #{crypto.symbol}:"
        puts "    24h: #{crypto.price_change_percentage_24h}% (#{crypto.price_change_24h_complete? ? 'vollständig' : 'unvollständig'})"
        puts "    1h:  #{crypto.price_change_percentage_1h}% (#{crypto.price_change_1h_complete? ? 'vollständig' : 'unvollständig'})"
        puts "    30min: #{crypto.price_change_percentage_30min}% (#{crypto.price_change_30min_complete? ? 'vollständig' : 'unvollständig'})"
      end
    end
  end
end
