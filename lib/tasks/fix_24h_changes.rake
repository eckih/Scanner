namespace :crypto do
  desc "Korrigiere 24h Änderungen für alle Kryptowährungen"
  task fix_24h_changes: :environment do
    puts "=== Korrigiere 24h Änderungen ==="
    
    Cryptocurrency.all.each do |crypto|
      puts "\n📊 Verarbeite #{crypto.symbol}..."
      
      # Suche 24h alte Daten
      twenty_four_hours_ago = Time.now - 24.hours
      historical_data_24h = CryptoHistoryData.where(
        cryptocurrency: crypto,
        timestamp: ..twenty_four_hours_ago,
        interval: '1m'
      ).order(:timestamp).last
      
      if historical_data_24h
        # Berechne korrekte 24h Änderung
        old_price = historical_data_24h.close_price
        current_price = crypto.current_price
        calculated_change = ((current_price - old_price) / old_price) * 100
        
        # Zeige alte vs neue Werte
        puts "  Alter Preis: #{old_price}"
        puts "  Aktueller Preis: #{current_price}"
        puts "  Alte 24h Änderung: #{crypto.price_change_percentage_24h}%"
        puts "  Neue 24h Änderung: #{calculated_change.round(2)}%"
        
        # Aktualisiere die Datenbank
        crypto.update!(
          price_change_percentage_24h: calculated_change.round(2),
          price_change_24h_complete: true,
          last_updated: Time.now
        )
        
        puts "  ✅ Aktualisiert!"
      else
        puts "  ❌ Keine 24h Daten verfügbar"
        crypto.update!(
          price_change_percentage_24h: 0.0,
          price_change_24h_complete: false,
          last_updated: Time.now
        )
      end
    end
    
    puts "\n🎉 24h Änderungen korrigiert!"
  end
end
