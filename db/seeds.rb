# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Creating fake cryptocurrency data..."

# Clear existing data
Cryptocurrency.destroy_all

# Create 50 fake cryptocurrencies
50.times do |i|
  crypto_names = [
    "Bitcoin", "Ethereum", "Binance Coin", "Cardano", "Solana", "XRP", "Polkadot", 
    "Dogecoin", "Avalanche", "Shiba Inu", "Polygon", "Cosmos", "Litecoin", "Chainlink",
    "Bitcoin Cash", "Algorand", "VeChain", "Stellar", "Filecoin", "TRON", "Monero",
    "EOS", "Aave", "Theta", "Maker", "Compound", "Uniswap", "Sushiswap", "Pancakeswap",
    "Curve", "Yearn Finance", "1inch", "Synthetix", "Ren", "Kyber Network", "0x",
    "Basic Attention Token", "Enjin Coin", "Chiliz", "Decentraland", "The Sandbox",
    "Axie Infinity", "Flow", "Internet Computer", "Near Protocol", "Fantom", "Harmony",
    "Kusama", "Elrond", "Zilliqa"
  ]
  
  crypto_symbols = [
    "BTC", "ETH", "BNB", "ADA", "SOL", "XRP", "DOT", "DOGE", "AVAX", "SHIB", 
    "MATIC", "ATOM", "LTC", "LINK", "BCH", "ALGO", "VET", "XLM", "FIL", "TRX",
    "XMR", "EOS", "AAVE", "THETA", "MKR", "COMP", "UNI", "SUSHI", "CAKE", "CRV",
    "YFI", "1INCH", "SNX", "REN", "KNC", "ZRX", "BAT", "ENJ", "CHZ", "MANA",
    "SAND", "AXS", "FLOW", "ICP", "NEAR", "FTM", "ONE", "KSM", "EGLD", "ZIL"
  ]
  
  name = crypto_names[i] || "CryptoCoin #{i + 1}"
  symbol = crypto_symbols[i] || "CC#{i + 1}"
  
  # Generate realistic market cap values
  market_cap = case i
  when 0..4    # Top 5 coins
    rand(100_000_000_000..1_000_000_000_000)
  when 5..9    # Top 10 coins
    rand(10_000_000_000..100_000_000_000)
  when 10..19  # Top 20 coins
    rand(1_000_000_000..10_000_000_000)
  else         # Other coins
    rand(100_000_000..1_000_000_000)
  end
  
  # Generate RSI values (0-100)
  rsi = rand(10.0..90.0).round(2)
  
  # Generate price
  price = case i
  when 0       # Bitcoin-like price
    rand(30_000.0..70_000.0)
  when 1       # Ethereum-like price
    rand(1_500.0..4_000.0)
  when 2..4    # Other major coins
    rand(100.0..1_000.0)
  when 5..9    # Mid-tier coins
    rand(1.0..100.0)
  else         # Smaller coins
    rand(0.01..10.0)
  end
  
  Cryptocurrency.create!(
    name: name,
    symbol: symbol,
    market_cap: market_cap,
    market_cap_rank: i + 1,
    current_price: price.round(6),
    rsi: rsi,
    last_updated: Time.current - rand(1..60).minutes
  )
end

puts "Created #{Cryptocurrency.count} cryptocurrencies!"
puts "Top 5 cryptocurrencies by market cap:"
Cryptocurrency.order(market_cap_rank: :asc).limit(5).each do |crypto|
  puts "#{crypto.market_cap_rank}. #{crypto.name} (#{crypto.symbol}) - $#{crypto.formatted_market_cap}"
end