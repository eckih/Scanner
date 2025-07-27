namespace :crypto do
  desc "Komplette Einrichtung: Synchronisiere DB und berechne RSI"
  task setup_complete: :environment do
    puts "🚀 Starte komplette Einrichtung..."
    
    # 1. Synchronisiere Datenbank mit Whitelist
    puts "\n📋 Schritt 1: Synchronisiere Datenbank mit Whitelist..."
    Rake::Task['crypto:sync_whitelist'].invoke
    
    puts "\n⏳ Warte 2 Sekunden..."
    sleep(2)
    
    # 2. Berechne RSI-Werte
    puts "\n📊 Schritt 2: Berechne RSI-Werte..."
    Rake::Task['crypto:calculate_rsi_now'].invoke
    
    puts "\n🎉 Komplette Einrichtung abgeschlossen!"
    puts "📊 Finale Statistik:"
    puts "  Kryptowährungen: #{Cryptocurrency.count}"
    puts "  Symbole: #{Cryptocurrency.pluck(:symbol).join(', ')}"
    puts "  RSI-Werte: #{Cryptocurrency.where.not(rsi: nil).count}/#{Cryptocurrency.count}"
  end
end 