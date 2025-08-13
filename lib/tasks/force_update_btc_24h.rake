require 'net/http'
require 'json'

namespace :crypto do
  desc "Korrigiere sofort BTC 24h Änderung"
  task force_update_btc_24h: :environment do
    puts "🚨 SOFORTIGE BTC KORREKTUR..."
    
    # Finde BTC
    btc = Cryptocurrency.find_by(symbol: 'BTC/USDC')
    
    if btc
      puts "💰 Gefunden: #{btc.symbol}"
      puts "   Aktueller Preis: $#{btc.current_price}"
      puts "   Aktuelle 24h Änderung: #{btc.price_change_percentage_24h}%"
      
      begin
        # Hole CoinGecko Daten für Bitcoin
        uri = URI("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          coingecko_data = JSON.parse(response.body)
          
          if coingecko_data['bitcoin']
            coingecko_24h_change = coingecko_data['bitcoin']['usd_24h_change'].to_f
            coingecko_price = coingecko_data['bitcoin']['usd'].to_f
            
            puts "\n📈 CoinGecko Daten:"
            puts "   Preis: $#{coingecko_price}"
            puts "   24h Änderung: #{coingecko_24h_change.round(2)}%"
            
            # Zeige Vergleich
            old_change = btc.price_change_percentage_24h || 0
            puts "\n📊 Vergleich:"
            puts "   Vorher: #{old_change}%"
            puts "   Nachher: #{coingecko_24h_change.round(2)}%"
            puts "   Differenz: #{(coingecko_24h_change - old_change).round(2)}%"
            
            # Aktualisiere BTC
            btc.update!(
              current_price: coingecko_price,
              price_change_percentage_24h: coingecko_24h_change.round(2),
              price_change_24h_complete: true,
              last_updated: Time.current
            )
            
            puts "\n✅ BTC erfolgreich aktualisiert!"
            puts "   Neuer Preis: $#{btc.reload.current_price}"
            puts "   Neue 24h Änderung: #{btc.price_change_percentage_24h}%"
            
          else
            puts "❌ Keine Bitcoin-Daten in CoinGecko Response"
          end
        else
          puts "❌ CoinGecko API Fehler (#{response.code}): #{response.body}"
        end
        
      rescue => e
        puts "❌ Fehler: #{e.message}"
      end
      
    else
      puts "❌ BTC/USDC nicht in der Datenbank gefunden"
    end
    
    puts "\n🔄 Starte WebSocket Service neu, um die Änderung zu übernehmen..."
    puts "💡 Die 24h Änderung sollte jetzt korrekt angezeigt werden."
  end
end
