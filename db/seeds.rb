# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Nur Daten laden, wenn die Datenbank leer ist
if Cryptocurrency.count == 0
  puts "Loading real cryptocurrency data from Binance API (first time setup)..."
  
  # Load cryptocurrency data
  puts "Fetching data for 55 USDC pairs..."
  CryptoDataLoader.load_real_cryptocurrency_data
  
  puts "Seeding completed successfully!"
else
  puts "Database already contains data. Skipping initial data load."
  puts "Data will be updated via scheduled background jobs."
end