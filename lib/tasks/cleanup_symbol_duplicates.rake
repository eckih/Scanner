namespace :crypto do
  desc "Bereinige Symbol-Duplikate und standardisiere Format"
  task cleanup_symbol_duplicates: :environment do
    puts "[REFRESH] Starte Symbol-Bereinigung..."
    
    # Definiere bevorzugte Formate (mit / für bessere Lesbarkeit)
    preferred_formats = {
      'BTC' => 'BTC/USDC',
      'ETH' => 'ETH/USDC', 
      'BNB' => 'BNB/USDC',
      'ADA' => 'ADA/USDC',
      'SOL' => 'SOL/USDC',
      'NEWT' => 'NEWT/USDC'  # Standardisiere auf USDC
    }
    
    puts "📊 Vorher: #{Cryptocurrency.count} Kryptowährungen"
    
    # Finde Duplikate
    symbols = Cryptocurrency.pluck(:symbol)
    duplicates = symbols.group_by { |s| s.gsub('/', '').gsub('USDC', '').gsub('USDT', '') }
                       .select { |k, v| v.length > 1 }
    
    puts "🔍 Gefundene Duplikate:"
    duplicates.each do |base, syms|
      puts "  #{base}: #{syms.join(', ')}"
    end
    
    # Bereinige Duplikate
    duplicates.each do |base_symbol, symbol_list|
      preferred_symbol = preferred_formats[base_symbol]
      
      if preferred_symbol && symbol_list.include?(preferred_symbol)
        # Behalte das bevorzugte Format
        keep_symbol = preferred_symbol
        delete_symbols = symbol_list - [preferred_symbol]
        
        puts "✅ Behalte: #{keep_symbol}"
        puts "🗑️  Lösche: #{delete_symbols.join(', ')}"
        
        # Migriere Daten von zu löschenden zu behaltenden Symbolen
        delete_symbols.each do |symbol_to_delete|
          crypto_to_delete = Cryptocurrency.find_by(symbol: symbol_to_delete)
          crypto_to_keep = Cryptocurrency.find_by(symbol: keep_symbol)
          
          if crypto_to_delete && crypto_to_keep
            puts "  📦 Migriere Daten von #{symbol_to_delete} zu #{keep_symbol}"
            
            # Migriere crypto_history_data
            migrated_count = CryptoHistoryData.where(cryptocurrency_id: crypto_to_delete.id)
                                            .update_all(cryptocurrency_id: crypto_to_keep.id)
            puts "    📊 #{migrated_count} crypto_history_data Einträge migriert"
            
            # Historie-Tabellen wurden bereits entfernt - keine Migration nötig
            
            # Aktualisiere den zu behaltenden Eintrag mit besseren Daten
            if crypto_to_delete.rsi && !crypto_to_keep.rsi
              crypto_to_keep.update!(rsi: crypto_to_delete.rsi)
              puts "    📊 RSI-Wert von #{symbol_to_delete} übernommen"
            end
            
            if crypto_to_delete.current_price && !crypto_to_keep.current_price
              crypto_to_keep.update!(current_price: crypto_to_delete.current_price)
              puts "    💰 Preis von #{symbol_to_delete} übernommen"
            end
            
            # Lösche den doppelten Eintrag
            crypto_to_delete.destroy!
            puts "    ✅ #{symbol_to_delete} gelöscht"
          end
        end
      else
        puts "[!]  Kein bevorzugtes Format für #{base_symbol} definiert"
      end
    end
    
    puts "📊 Nachher: #{Cryptocurrency.count} Kryptowährungen"
    
    # Zeige finale Liste
    puts "✅ Finale Kryptowährungen:"
    Cryptocurrency.order(:symbol).each do |crypto|
      puts "  #{crypto.symbol} - RSI: #{crypto.rsi || 'N/A'}"
    end
    
    puts "🎉 Symbol-Bereinigung abgeschlossen!"
  end
end 