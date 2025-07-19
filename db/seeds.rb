# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Loading real cryptocurrency data from Binance API..."

# Load cryptocurrency data
puts "Fetching data for 55 USDC pairs..."
loader = CryptoDataLoader.new
loader.load_data

puts "Seeding completed successfully!"