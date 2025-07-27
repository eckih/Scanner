namespace :crypto do
  desc "Bereinige Datenbank - behalte nur Whitelist-Paare"
  task cleanup_database: :environment do
    puts "🧹 Bereinige Datenbank..."
    
    # Lade Whitelist
    config_path = Rails.root.join('config', 'bot.json')
    unless File.exist?(config_path)
      puts "❌ bot.json nicht gefunden"
      return
    end
    
    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    
    puts "📋 Whitelist: #{whitelist.join(', ')}"
    
    # Aktuelle Kryptowährungen
    current_cryptos = Cryptocurrency.pluck(:symbol)
    puts "📊 Aktuelle Kryptowährungen: #{current_cryptos.join(', ')}"
    
    # Finde zu löschende Kryptowährungen
    to_delete = current_cryptos - whitelist
    
    if to_delete.any?
      puts "\n🗑️ Lösche nicht-whitelistierte Kryptowährungen: #{to_delete.join(', ')}"
      
      to_delete.each do |symbol|
        crypto = Cryptocurrency.find_by(symbol: symbol)
        if crypto
          # Lösche zugehörige Daten
          CryptoHistoryData.where(cryptocurrency: crypto).delete_all
          RsiHistory.where(cryptocurrency: crypto).delete_all
          RocHistory.where(cryptocurrency: crypto).delete_all
          RocDerivativeHistory.where(cryptocurrency: crypto).delete_all
          
          crypto.destroy
          puts "✅ #{symbol} gelöscht"
        end
      end
    else
      puts "\n✅ Keine zu löschenden Kryptowährungen gefunden"
    end
    
    puts "\n📊 Finale Datenbankstatistik:"
    puts "  Kryptowährungen: #{Cryptocurrency.count}"
    puts "  Symbole: #{Cryptocurrency.pluck(:symbol).join(', ')}"
  end
end 