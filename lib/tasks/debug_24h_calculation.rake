namespace :crypto do
  desc "Debug 24h Berechnung für BTC"
  task debug_24h_calculation: :environment do
    puts "=== BTC 24h Berechnung Debug ==="
    
    # Zeige alle verfügbaren Kryptowährungen
    puts "Verfügbare Kryptowährungen:"
    Cryptocurrency.all.each do |crypto|
      puts "  #{crypto.symbol}: #{crypto.name}"
    end
    puts
    
    # Finde BTC
    btc = Cryptocurrency.find_by(symbol: 'BTCUSDC')
    if btc.nil?
      puts "❌ BTCUSDC nicht gefunden!"
      puts "Versuche alternative Symbole..."
      
      # Versuche andere BTC-Symbole
      btc = Cryptocurrency.find_by(symbol: 'BTC')
      if btc.nil?
        btc = Cryptocurrency.where("symbol LIKE '%BTC%'").first
      end
      
      if btc.nil?
        puts "❌ Kein BTC-Symbol gefunden!"
        next
      else
        puts "✅ BTC gefunden mit Symbol: #{btc.symbol}"
      end
    else
      puts "✅ BTC gefunden"
    end
    
    puts "Aktueller Preis: #{btc.current_price}"
    puts "24h Änderung: #{btc.price_change_percentage_24h}%"
    puts "24h Vollständig: #{btc.price_change_24h_complete}"
    puts "Letzte Aktualisierung: #{btc.last_updated}"
    puts
    
    # Suche 24h alte Daten
    twenty_four_hours_ago = Time.now - 24.hours
    puts "Suche nach Daten von vor 24h (#{twenty_four_hours_ago})"
    
    historical_data_24h = CryptoHistoryData.where(
      cryptocurrency: btc,
      timestamp: ..twenty_four_hours_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data_24h
      puts "✅ 24h alte Daten gefunden:"
      puts "  Preis: #{historical_data_24h.close_price}"
      puts "  Timestamp: #{historical_data_24h.timestamp}"
      puts "  Zeitdifferenz: #{((Time.now - historical_data_24h.timestamp) / 3600).round(2)} Stunden"
      
      # Berechne 24h Änderung
      old_price = historical_data_24h.close_price
      current_price = btc.current_price
      calculated_change = ((current_price - old_price) / old_price) * 100
      
      puts
      puts "📊 Berechnung:"
      puts "  Alter Preis: #{old_price}"
      puts "  Aktueller Preis: #{current_price}"
      puts "  Berechnete Änderung: #{calculated_change.round(2)}%"
      puts "  Gespeicherte Änderung: #{btc.price_change_percentage_24h}%"
      puts "  Differenz: #{(calculated_change - btc.price_change_percentage_24h).round(2)}%"
    else
      puts "❌ Keine 24h alten Daten gefunden!"
      
      # Zeige die letzten verfügbaren Daten
      puts
      puts "Letzte verfügbare Daten:"
      recent_data = CryptoHistoryData.where(cryptocurrency: btc, interval: '1m').order(:timestamp).last(5)
      recent_data.each do |data|
        hours_ago = ((Time.now - data.timestamp) / 3600).round(2)
        puts "  #{data.timestamp} (#{hours_ago}h ago): #{data.close_price}"
      end
    end
    
    puts
    puts "=== Ende Debug ==="
  end
end
