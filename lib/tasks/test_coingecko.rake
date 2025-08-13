require 'net/http'
require 'json'

namespace :crypto do
  desc "Teste CoinGecko API für Bitcoin"
  task test_coingecko: :environment do
    puts "🧪 Teste CoinGecko API für Bitcoin..."
    
    begin
      # Teste CoinGecko API für Bitcoin
      uri = URI("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        coingecko_data = JSON.parse(response.body)
        puts "✅ CoinGecko Bitcoin:"
        puts "   Preis: $#{coingecko_data['bitcoin']['usd']}"
        puts "   24h Änderung: #{coingecko_data['bitcoin']['usd_24h_change']}%"
        
        # Vergleiche mit aktueller Datenbank
        btc_crypto = Cryptocurrency.find_by(symbol: 'BTC/USDC')
        if btc_crypto
          puts "\n📊 Vergleich mit Datenbank:"
          puts "   Datenbank 24h Änderung: #{btc_crypto.price_change_percentage_24h}%"
          puts "   CoinGecko 24h Änderung: #{coingecko_data['bitcoin']['usd_24h_change']}%"
          puts "   Differenz: #{(btc_crypto.price_change_percentage_24h - coingecko_data['bitcoin']['usd_24h_change']).round(2)}%"
        end
      else
        puts "❌ CoinGecko Fehler (#{response.code}): #{response.body}"
      end
    rescue => e
      puts "❌ CoinGecko Exception: #{e.message}"
    end
  end
end
