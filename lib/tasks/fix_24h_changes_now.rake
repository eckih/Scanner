require 'net/http'
require 'json'

namespace :crypto do
  desc "Korrigiere sofort alle 24h Änderungen mit CoinGecko API"
  task fix_24h_changes_now: :environment do
    puts "🚨 SOFORTIGE KORREKTUR: 24h Änderungen mit CoinGecko API..."
    
    # Hole alle Kryptowährungen
    cryptocurrencies = Cryptocurrency.all
    puts "📊 Korrigiere 24h Änderungen für #{cryptocurrencies.count} Kryptowährungen..."
    
    updated_count = 0
    error_count = 0
    
    cryptocurrencies.each do |crypto|
      begin
        puts "\n💰 Korrigiere 24h Änderung für #{crypto.symbol}..."
        
        # Verwende CoinGecko API für genaue 24h Änderung
        coin_id = get_coingecko_coin_id(crypto.symbol)
        
        if coin_id
          # Hole 24h Änderung von CoinGecko API
          uri = URI("https://api.coingecko.com/api/v3/simple/price?ids=#{coin_id}&vs_currencies=usd&include_24hr_change=true")
          response = Net::HTTP.get_response(uri)
          
          if response.code == '200'
            coingecko_data = JSON.parse(response.body)
            
            if coingecko_data[coin_id]
              coingecko_24h_change = coingecko_data[coin_id]['usd_24h_change'].to_f
              coingecko_price = coingecko_data[coin_id]['usd'].to_f
              
              # Zeige vorher/nachher Vergleich
              old_change = crypto.price_change_percentage_24h || 0
              puts "   Vorher: #{old_change}%"
              puts "   Nachher: #{coingecko_24h_change.round(2)}%"
              puts "   Differenz: #{(coingecko_24h_change - old_change).round(2)}%"
              
              # Aktualisiere Kryptowährung
              crypto.update!(
                current_price: coingecko_price,
                price_change_percentage_24h: coingecko_24h_change.round(2),
                price_change_24h_complete: true,
                last_updated: Time.current
              )
              
              puts "✅ #{crypto.symbol}: #{coingecko_24h_change.round(2)}% (Preis: $#{coingecko_price}) [CoinGecko]"
              updated_count += 1
            else
              puts "❌ #{crypto.symbol}: Keine Daten in CoinGecko Response"
              error_count += 1
            end
          else
            puts "❌ #{crypto.symbol}: CoinGecko API Fehler (#{response.code})"
            error_count += 1
          end
        else
          puts "❌ #{crypto.symbol}: Keine CoinGecko ID gefunden"
          error_count += 1
        end
        
        # Kurze Pause zwischen API-Aufrufen
        sleep(0.2)
        
      rescue => e
        puts "❌ Fehler bei #{crypto.symbol}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\n🎉 SOFORTIGE KORREKTUR abgeschlossen!"
    puts "📊 Statistik:"
    puts "  Erfolgreich korrigiert: #{updated_count}"
    puts "  Fehler: #{error_count}"
    puts "  Gesamt: #{cryptocurrencies.count}"
    
    if updated_count > 0
      puts "\n📈 Korrigierte 24h Änderungen:"
      cryptocurrencies.reload.each do |crypto|
        change = crypto.price_change_percentage_24h
        color = change >= 0 ? "🟢" : "🔴"
        puts "  #{color} #{crypto.symbol}: #{change}%"
      end
    end
    
    puts "\n🔄 Starte WebSocket Service neu, um die Änderungen zu übernehmen..."
    puts "💡 Führe 'rails runner \"Rake::Task['crypto:fix_24h_changes_now'].invoke\"' aus, um die Korrektur zu starten."
  end
  
  private
  
  def self.get_coingecko_coin_id(symbol)
    # Mapping von Symbolen zu CoinGecko IDs
    coin_mapping = {
      'BTC/USDC' => 'bitcoin',
      'ETH/USDC' => 'ethereum',
      'BNB/USDC' => 'binancecoin',
      'ADA/USDC' => 'cardano',
      'SOL/USDC' => 'solana',
      'XRP/USDC' => 'ripple',
      'DOT/USDC' => 'polkadot',
      'DOGE/USDC' => 'dogecoin',
      'AVAX/USDC' => 'avalanche-2',
      'SHIB/USDC' => 'shiba-inu',
      'MATIC/USDC' => 'matic-network',
      'LTC/USDC' => 'litecoin',
      'UNI/USDC' => 'uniswap',
      'LINK/USDC' => 'chainlink',
      'ATOM/USDC' => 'cosmos',
      'XLM/USDC' => 'stellar',
      'BCH/USDC' => 'bitcoin-cash',
      'ALGO/USDC' => 'algorand',
      'VET/USDC' => 'vechain',
      'FIL/USDC' => 'filecoin',
      'TRX/USDC' => 'tron',
      'ETC/USDC' => 'ethereum-classic',
      'THETA/USDC' => 'theta-token',
      'FTM/USDC' => 'fantom',
      'HBAR/USDC' => 'hedera-hashgraph',
      'EOS/USDC' => 'eos',
      'AAVE/USDC' => 'aave',
      'NEO/USDC' => 'neo',
      'MKR/USDC' => 'maker',
      'COMP/USDC' => 'compound-governance-token',
      'YFI/USDC' => 'yearn-finance',
      'SNX/USDC' => 'havven',
      'DASH/USDC' => 'dash',
      'ZEC/USDC' => 'zcash',
      'ENJ/USDC' => 'enjincoin',
      'MANA/USDC' => 'decentraland',
      'SAND/USDC' => 'the-sandbox',
      'CHZ/USDC' => 'chiliz',
      'BAT/USDC' => 'basic-attention-token',
      'ZIL/USDC' => 'zilliqa',
      'ICX/USDC' => 'icon',
      'ONT/USDC' => 'ontology',
      'QTUM/USDC' => 'qtum',
      'ZRX/USDC' => '0x',
      'OMG/USDC' => 'omisego',
      'LRC/USDC' => 'loopring',
      'STORJ/USDC' => 'storj',
      'CVC/USDC' => 'civic',
      'KNC/USDC' => 'kyber-network',
      'NEAR/USDC' => 'near',
      'CAKE/USDC' => 'pancakeswap-token',
      'AXS/USDC' => 'axie-infinity',
      'GALA/USDC' => 'gala',
      'APE/USDC' => 'apecoin',
      'GMT/USDC' => 'stepn',
      'NEWT/USDC' => 'newton-project'
    }
    
    coin_mapping[symbol]
  end
end
