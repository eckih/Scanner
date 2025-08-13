#!/usr/bin/env ruby

require 'net/http'
require 'json'

puts "🧪 Teste CoinGecko API direkt..."

begin
  # Teste CoinGecko API für Bitcoin
  uri = URI("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    coingecko_data = JSON.parse(response.body)
    puts "✅ CoinGecko Bitcoin:"
    puts "   Preis: $#{coingecko_data['bitcoin']['usd']}"
    puts "   24h Änderung: #{coingecko_data['bitcoin']['usd_24h_change']}%"
    
    # Teste auch Ethereum
    uri_eth = URI("https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd&include_24hr_change=true")
    response_eth = Net::HTTP.get_response(uri_eth)
    
    if response_eth.code == '200'
      eth_data = JSON.parse(response_eth.body)
      puts "\n✅ CoinGecko Ethereum:"
      puts "   Preis: $#{eth_data['ethereum']['usd']}"
      puts "   24h Änderung: #{eth_data['ethereum']['usd_24h_change']}%"
    end
    
  else
    puts "❌ CoinGecko Fehler (#{response.code}): #{response.body}"
  end
rescue => e
  puts "❌ CoinGecko Exception: #{e.message}"
end

puts "\n🔍 Teste auch Binance API für Vergleich..."

begin
  # Teste Binance API für BTCUSDT
  uri_binance = URI("https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT")
  response_binance = Net::HTTP.get_response(uri_binance)
  
  if response_binance.code == '200'
    binance_data = JSON.parse(response_binance.body)
    puts "✅ Binance BTCUSDT:"
    puts "   Symbol: #{binance_data['symbol']}"
    puts "   Preis: $#{binance_data['lastPrice']}"
    puts "   24h Änderung: #{binance_data['priceChangePercent']}%"
  else
    puts "❌ Binance Fehler (#{response_binance.code}): #{response_binance.body}"
  end
rescue => e
  puts "❌ Binance Exception: #{e.message}"
end

puts "\n🎯 Fazit:"
puts "Die CoinGecko API sollte die korrekten 24h Änderungen liefern."
puts "Führe die Rake-Task aus, um die Datenbank zu korrigieren."
