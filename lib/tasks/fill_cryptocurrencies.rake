namespace :crypto do
  desc "Fill Cryptocurrency table with pairs from bot.json"
  task fill_from_bot_json: :environment do
    require 'json'
    
    puts "🧹 Lösche bestehende Cryptocurrencies..."
    Cryptocurrency.delete_all
    
    puts "📊 Lade Pairs aus bot.json..."
    bot_config = JSON.parse(File.read('config/bot.json'))
    whitelist_pairs = bot_config['exchange']['pair_whitelist']
    
    puts "📋 Whitelist Pairs: #{whitelist_pairs.join(', ')}"
    
    whitelist_pairs.each_with_index do |pair, index|
      crypto = Cryptocurrency.create!(
        symbol: pair,
        name: pair.split('/').first,
        current_price: 1.0,
        market_cap: 1000000,
        market_cap_rank: index + 1
      )
      puts "✅ #{pair} → ID #{crypto.id}"
    end
    
    puts "\n📊 Finale Übersicht:"
    Cryptocurrency.all.order(:id).each { |c| puts "  ID #{c.id}: #{c.symbol}" }
    puts "\n✅ #{Cryptocurrency.count} Pairs erfolgreich erstellt"
  end
end 