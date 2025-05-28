# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Loading real cryptocurrency data from Binance API..."

# Clear existing data
Cryptocurrency.destroy_all

begin
  # Verwende den BinanceService um echte Daten zu laden
  top_symbols = BinanceService.get_top_usdc_pairs
  puts "Fetching data for #{top_symbols.length} USDC pairs..."
  
  BinanceService.fetch_specific_cryptos(top_symbols)
  
  puts "Successfully loaded #{Cryptocurrency.count} cryptocurrencies from Binance!"
  puts "Top 5 cryptocurrencies by market cap:"
  Cryptocurrency.order(market_cap_rank: :asc).limit(5).each do |crypto|
    puts "#{crypto.market_cap_rank}. #{crypto.name} (#{crypto.symbol}) - #{crypto.formatted_current_price}"
  end
  
rescue StandardError => e
  puts "Error loading data from Binance API: #{e.message}"
  puts "Creating minimal fallback data..."
  
  # Fallback: Erstelle nur ein paar Basis-Einträge ohne Fake-Daten
  [
    { name: "Bitcoin", symbol: "BTCUSDC", price: 50000.0 },
    { name: "Ethereum", symbol: "ETHUSDC", price: 3000.0 },
    { name: "Binance Coin", symbol: "BNBUSDC", price: 400.0 }
  ].each_with_index do |crypto_data, index|
    Cryptocurrency.create!(
      name: crypto_data[:name],
      symbol: crypto_data[:symbol],
      market_cap: crypto_data[:price] * 1_000_000, # Einfache Market Cap Berechnung
      market_cap_rank: index + 1,
      current_price: crypto_data[:price],
      rsi: 50.0, # Neutral RSI
      last_updated: Time.current
    )
  end
  
  puts "Created #{Cryptocurrency.count} fallback cryptocurrencies."
end