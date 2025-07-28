namespace :crypto do
  desc "Komplette Einrichtung: Whitelist synchronisieren + Historische Daten laden + RSI berechnen"
  task setup_complete_v2: :environment do
    puts "🚀 Starte komplette Crypto-Scanner Einrichtung..."
    puts "="*70
    
    begin
      # Schritt 1: Datenbank aufräumen und synchronisieren
      puts "\n📋 Schritt 1: Whitelist synchronisieren..."
      puts "-" * 50
      
      Rake::Task['crypto:sync_whitelist'].invoke
      puts "✅ Whitelist-Synchronisation abgeschlossen"
      
      # Schritt 2: Historische Daten für alle Pairs laden
      puts "\n📊 Schritt 2: Historische Daten laden (letzte 2 Tage)..."
      puts "-" * 50
      
      Rake::Task['crypto:load_all_whitelist_data'].invoke
      puts "✅ Historische Daten erfolgreich geladen"
      
      # Schritt 3: Finale Statistiken
      puts "\n📈 Schritt 3: Finale Überprüfung..."
      puts "-" * 50
      
      whitelist = load_whitelist_pairs
      total_cryptos = 0
      total_historical = 0
      total_rsi = 0
      
      whitelist.each do |pair|
        crypto = Cryptocurrency.find_by(symbol: pair)
        next unless crypto
        
        historical_count = CryptoHistoryData.where(cryptocurrency: crypto).count
        indicator_count = Indicator.where(cryptocurrency: crypto).count
        
        total_cryptos += 1
        total_historical += historical_count
        total_rsi += indicator_count
        
        puts "✅ #{pair}: #{historical_count} historische Datensätze, #{indicator_count} Indikator-Werte"
      end
      
      puts "\n" + "="*70
      puts "🎉 SETUP ERFOLGREICH ABGESCHLOSSEN!"
      puts "="*70
      puts "📊 Zusammenfassung:"
      puts "   Kryptowährungen: #{total_cryptos}"
      puts "   Historische Datensätze: #{total_historical}"
      puts "   Indikator-Datensätze: #{total_rsi}"
      puts "   Verfügbare Timeframes: 1m, 5m, 15m, 1h, 4h"
      puts "\n🚀 Der Crypto-Scanner ist jetzt einsatzbereit!"
      puts "📱 Öffnen Sie: http://localhost:3005/cryptocurrencies"
      puts "🗄️ Datenbank-Admin: http://localhost:3006 (falls Adminer läuft)"
      
    rescue => e
      puts "\n❌ Fehler beim Setup: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
  
  private
  
  def self.load_whitelist_pairs
    config_path = Rails.root.join('config', 'bot.json')
    return [] unless File.exist?(config_path)
    
    begin
      config = JSON.parse(File.read(config_path))
      config.dig('exchange', 'pair_whitelist') || []
    rescue => e
      Rails.logger.error "Fehler beim Laden der bot.json: #{e.message}"
      []
    end
  end
end 