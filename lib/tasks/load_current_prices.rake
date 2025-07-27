require 'net/http'
require 'json'

namespace :crypto do
  desc "Lade aktuelle Preise von Binance API"
  task load_current_prices: :environment do
    puts "💰 Lade aktuelle Preise von Binance API..."
    
    # Lade Whitelist
    config_path = Rails.root.join('config', 'bot.json')
    unless File.exist?(config_path)
      puts "❌ bot.json nicht gefunden"
      return
    end
    
    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    
    puts "📋 Whitelist: #{whitelist.join(', ')}"
    
    # Hole nur Whitelist-Kryptowährungen
    cryptocurrencies = Cryptocurrency.where(symbol: whitelist)
    puts "📊 Lade Preise für #{cryptocurrencies.count} Kryptowährungen..."
    
    cryptocurrencies.each do |crypto|
      begin
        puts "\n💰 Lade Preis für #{crypto.symbol}..."
        
        # Konvertiere Symbol für Binance (BTC/USDC -> BTCUSDC)
        binance_symbol = crypto.symbol.gsub('/', '').upcase
        
        # Hole Preis von Binance API
        price_data = fetch_binance_ticker(binance_symbol)
        
        if price_data
          # Aktualisiere Kryptowährung
          crypto.update!(
            current_price: price_data['price'].to_f,
            price_change_percentage_24h: price_data['priceChangePercent'].to_f,
            volume_24h: (price_data['volume'].to_f * price_data['price'].to_f),
            last_updated: Time.current
          )
          
          puts "✅ #{crypto.symbol}: $#{price_data['price']} (#{price_data['priceChangePercent']}%)"
        else
          puts "❌ #{crypto.symbol}: Keine Preisdaten gefunden"
        end
        
        # Kurze Pause zwischen API-Aufrufen
        sleep(0.1)
        
      rescue => e
        puts "❌ Fehler bei #{crypto.symbol}: #{e.message}"
      end
    end
    
    puts "\n🎉 Preis-Update abgeschlossen!"
    puts "📊 Finale Preise:"
    cryptocurrencies.reload.each do |crypto|
      if crypto.current_price && crypto.current_price > 0
        formatted_price = crypto.current_price >= 1 ? 
          "$#{crypto.current_price.round(2)}" : 
          "$#{crypto.current_price.round(6)}"
        puts "  #{crypto.symbol}: #{formatted_price}"
      else
        puts "  #{crypto.symbol}: N/A"
      end
    end
  end
  
  private
  
  def self.fetch_binance_ticker(symbol)
    begin
      # Binance API für 24h Ticker
      uri = URI("https://api.binance.com/api/v3/ticker/24hr?symbol=#{symbol}")
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        return {
          'price' => data['lastPrice'],
          'priceChangePercent' => data['priceChangePercent'],
          'volume' => data['volume']
        }
      else
        puts "⚠️ Binance API Fehler für #{symbol}: #{response.code}"
        return nil
      end
    rescue => e
      puts "❌ Netzwerk-Fehler für #{symbol}: #{e.message}"
      return nil
    end
  end
end 