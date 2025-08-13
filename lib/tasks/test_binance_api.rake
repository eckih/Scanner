require 'net/http'
require 'json'

namespace :crypto do
  desc "Teste Binance API für verschiedene Symbol-Formate"
  task test_binance_api: :environment do
    puts "🧪 Teste Binance API für verschiedene Symbol-Formate..."
    
    test_symbols = [
      'BTCUSDC',
      'BTCUSDT', 
      'BTCUSD',
      'BTC'
    ]
    
    test_symbols.each do |symbol|
      puts "\n🔍 Teste Symbol: #{symbol}"
      
      begin
        # Teste 24h Ticker API
        uri = URI("https://api.binance.com/api/v3/ticker/24hr?symbol=#{symbol}")
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          ticker_data = JSON.parse(response.body)
          puts "✅ Erfolgreich:"
          puts "   Symbol: #{ticker_data['symbol']}"
          puts "   Preis: $#{ticker_data['lastPrice']}"
          puts "   24h Änderung: #{ticker_data['priceChangePercent']}%"
          puts "   Volume: #{ticker_data['volume']}"
        else
          puts "❌ Fehler (#{response.code}): #{response.body}"
        end
        
        # Kurze Pause
        sleep(0.2)
        
      rescue => e
        puts "❌ Exception: #{e.message}"
      end
    end
    
    puts "\n🔍 Teste auch CoinGecko API für Vergleich..."
    
    begin
      # Teste CoinGecko API für Bitcoin
      uri = URI("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        coingecko_data = JSON.parse(response.body)
        puts "✅ CoinGecko Bitcoin:"
        puts "   Preis: $#{coingecko_data['bitcoin']['usd']}"
        puts "   24h Änderung: #{coingecko_data['bitcoin']['usd_24h_change']}%"
      else
        puts "❌ CoinGecko Fehler (#{response.code})"
      end
    rescue => e
      puts "❌ CoinGecko Exception: #{e.message}"
    end
  end
end
