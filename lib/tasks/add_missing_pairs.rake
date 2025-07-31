namespace :crypto do
  desc "Füge fehlende Pairs aus bot.json zur Datenbank hinzu"
  task add_missing_pairs: :environment do
    puts "🔍 Prüfe fehlende Pairs aus bot.json..."
    
    # Lade bot.json
    config_path = File.join(Rails.root, 'config', 'bot.json')
    unless File.exist?(config_path)
      puts "❌ bot.json nicht gefunden: #{config_path}"
      exit 1
    end
    
    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    
    puts "📋 Pairs in bot.json: #{whitelist.join(', ')}"
    
    # Aktuelle Pairs in DB
    existing_pairs = Cryptocurrency.pluck(:symbol)
    puts "💾 Pairs in DB: #{existing_pairs.join(', ')}"
    
    # Fehlende Pairs finden
    missing_pairs = whitelist - existing_pairs
    
    if missing_pairs.empty?
      puts "✅ Alle Pairs bereits vorhanden!"
      exit 0
    end
    
    puts "➕ Fehlende Pairs: #{missing_pairs.join(', ')}"
    puts ""
    
    # Fehlende Pairs hinzufügen
    missing_pairs.each do |pair|
      begin
        # Extrahiere Coin-Name aus dem Pair (z.B. "XRP/USDC" -> "XRP")
        coin_name = pair.split('/').first
        
        crypto = Cryptocurrency.create!(
          symbol: pair,
          name: coin_name,
          current_price: 1.0,  # Dummy-Wert, wird vom WebSocket aktualisiert
          market_cap: 1_000_000,  # Dummy-Wert
          market_cap_rank: 999  # Dummy-Wert
        )
        
        puts "✅ #{pair} hinzugefügt (ID: #{crypto.id})"
      rescue => e
        puts "❌ Fehler beim Hinzufügen von #{pair}: #{e.message}"
      end
    end
    
    puts ""
    puts "🎉 Fertig! #{missing_pairs.count} neue Pairs hinzugefügt."
    puts "[REFRESH] Starten Sie den WebSocket-Service neu, um die neuen Pairs zu aktivieren."
  end
end