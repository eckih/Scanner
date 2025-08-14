namespace :crypto do
  desc "Debug alle Zeitrahmen (24h, 1h, 30min) für mehrere Kryptowährungen"
  task debug_all_timeframes: :environment do
    puts "=== Debug aller Zeitrahmen ==="
    
    # Teste mit den ersten 5 Kryptowährungen
    cryptocurrencies = Cryptocurrency.limit(5)
    
    cryptocurrencies.each do |crypto|
      puts "\n📊 #{crypto.symbol} (#{crypto.name})"
      puts "Aktueller Preis: #{crypto.current_price}"
      
      # 24h Berechnung
      twenty_four_hours_ago = Time.now - 24.hours
      historical_data_24h = CryptoHistoryData.where(
        cryptocurrency: crypto,
        timestamp: ..twenty_four_hours_ago,
        interval: '1m'
      ).order(:timestamp).last
      
      if historical_data_24h
        old_price_24h = historical_data_24h.close_price
        change_24h = ((crypto.current_price - old_price_24h) / old_price_24h) * 100
        puts "  24h: #{change_24h.round(2)}% (von #{old_price_24h} auf #{crypto.current_price})"
      else
        puts "  24h: Keine Daten"
      end
      
      # 1h Berechnung
      one_hour_ago = Time.now - 1.hour
      historical_data_1h = CryptoHistoryData.where(
        cryptocurrency: crypto,
        timestamp: ..one_hour_ago,
        interval: '1m'
      ).order(:timestamp).last
      
      if historical_data_1h
        old_price_1h = historical_data_1h.close_price
        change_1h = ((crypto.current_price - old_price_1h) / old_price_1h) * 100
        puts "  1h:  #{change_1h.round(2)}% (von #{old_price_1h} auf #{crypto.current_price})"
      else
        puts "  1h:  Keine Daten"
      end
      
      # 30min Berechnung
      thirty_minutes_ago = Time.now - 30.minutes
      historical_data_30min = CryptoHistoryData.where(
        cryptocurrency: crypto,
        timestamp: ..thirty_minutes_ago,
        interval: '1m'
      ).order(:timestamp).last
      
      if historical_data_30min
        old_price_30min = historical_data_30min.close_price
        change_30min = ((crypto.current_price - old_price_30min) / old_price_30min) * 100
        puts "  30min: #{change_30min.round(2)}% (von #{old_price_30min} auf #{crypto.current_price})"
      else
        puts "  30min: Keine Daten"
      end
      
      # Zeige die letzten 5 historischen Datenpunkte
      puts "  Letzte 5 Datenpunkte:"
      recent_data = CryptoHistoryData.where(cryptocurrency: crypto, interval: '1m').order(:timestamp).last(5)
      recent_data.each do |data|
        hours_ago = ((Time.now - data.timestamp) / 3600).round(2)
        puts "    #{data.timestamp} (#{hours_ago}h ago): #{data.close_price}"
      end
    end
    
    puts "\n=== Ende Debug ==="
  end
end
