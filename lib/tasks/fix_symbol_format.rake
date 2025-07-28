require 'net/http'
require 'json'

namespace :crypto do
  desc "Standardisiere Kryptowährungs-Symbole und entferne Duplikate"
  task fix_symbol_format: :environment do
    puts "🔧 Standardisiere Kryptowährungs-Symbole..."
    
    # Lade bot.json Konfiguration für Referenz
    config_path = Rails.root.join('config', 'bot.json')
    if File.exist?(config_path)
      config = JSON.parse(File.read(config_path))
      whitelist = config.dig('exchange', 'pair_whitelist') || []
      puts "📋 Whitelist Format: #{whitelist.join(', ')}"
    end
    
    # Aktuelle Kryptowährungen
    current_cryptos = Cryptocurrency.all
    puts "📊 Aktuelle Kryptowährungen: #{current_cryptos.pluck(:symbol).join(', ')}"
    
    # Gruppiere nach normalisiertem Symbol
    grouped_cryptos = {}
    current_cryptos.each do |crypto|
      # Normalisiere Symbol zu "BTC/USDC" Format
      normalized_symbol = normalize_symbol(crypto.symbol)
      grouped_cryptos[normalized_symbol] ||= []
      grouped_cryptos[normalized_symbol] << crypto
    end
    
    puts "\n🔍 Gefundene Duplikate:"
    duplicates_found = false
    
    grouped_cryptos.each do |normalized_symbol, cryptos|
      if cryptos.length > 1
        duplicates_found = true
        puts "  #{normalized_symbol}: #{cryptos.map(&:symbol).join(', ')}"
      end
    end
    
    if !duplicates_found
      puts "  ✅ Keine Duplikate gefunden"
    end
    
    # Behebe Duplikate
    puts "\n🔄 Behebe Duplikate..."
    
    grouped_cryptos.each do |normalized_symbol, cryptos|
      if cryptos.length > 1
        puts "  Verarbeite #{normalized_symbol}..."
        
        # Wähle den ersten Eintrag als Haupt-Eintrag (bevorzuge das korrekte Format)
        main_crypto = cryptos.find { |c| c.symbol == normalized_symbol } || cryptos.first
        
        puts "    Haupt-Eintrag: #{main_crypto.symbol}"
        
        # Aktualisiere den Haupt-Eintrag auf das korrekte Format
        if main_crypto.symbol != normalized_symbol
          puts "    Aktualisiere Symbol von '#{main_crypto.symbol}' zu '#{normalized_symbol}'"
          main_crypto.update!(symbol: normalized_symbol)
        end
        
        # Lösche die anderen Duplikate
        cryptos.each do |crypto|
          next if crypto.id == main_crypto.id
          
          puts "    Lösche Duplikat: #{crypto.symbol}"
          
          # Lösche zugehörige historische Daten
          CryptoHistoryData.where(cryptocurrency: crypto).delete_all
          Indicator.where(cryptocurrency: crypto).delete_all
          
          crypto.destroy
        end
      end
    end
    
    # Aktualisiere alle Symbole auf das korrekte Format
    puts "\n📝 Standardisiere alle Symbole..."
    
    Cryptocurrency.all.each do |crypto|
      normalized_symbol = normalize_symbol(crypto.symbol)
      if crypto.symbol != normalized_symbol
        puts "  #{crypto.symbol} → #{normalized_symbol}"
        crypto.update!(symbol: normalized_symbol)
      end
    end
    
    puts "\n✅ Symbol-Standardisierung abgeschlossen!"
    puts "📊 Finale Kryptowährungen: #{Cryptocurrency.pluck(:symbol).join(', ')}"
  end
  
  private
  
  def self.normalize_symbol(symbol)
    # Entferne "/" falls vorhanden und füge es wieder hinzu
    base = symbol.gsub('/', '').gsub('USDC', '').gsub('USDT', '')
    
    # Füge "/USDC" hinzu (oder "/USDT" falls ursprünglich USDT)
    if symbol.include?('USDT')
      "#{base}/USDT"
    else
      "#{base}/USDC"
    end
  end
end 