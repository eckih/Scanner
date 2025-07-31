require 'net/http'
require 'json'

namespace :crypto do
  desc "Synchronisiere Datenbank mit der bot.json Whitelist"
  task sync_whitelist: :environment do
    puts "[REFRESH] Synchronisiere Datenbank mit bot.json Whitelist..."
    
    # Lade bot.json Konfiguration
    config_path = Rails.root.join('config', 'bot.json')
    unless File.exist?(config_path)
      puts "❌ Konfigurationsdatei nicht gefunden: #{config_path}"
      return
    end
    
    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    
    if whitelist.empty?
      puts "❌ Keine Paare in der Whitelist gefunden"
      return
    end
    
    puts "📋 Whitelist Paare: #{whitelist.join(', ')}"
    
    # Aktuelle Kryptowährungen in der Datenbank
    current_cryptos = Cryptocurrency.pluck(:symbol)
    puts "📊 Aktuelle Kryptowährungen in DB: #{current_cryptos.join(', ')}"
    
    # Finde zu entfernende Kryptowährungen (in DB aber nicht in Whitelist)
    to_remove = current_cryptos - whitelist
    if to_remove.any?
      puts "\n🗑️ Entferne nicht-whitelistierte Kryptowährungen: #{to_remove.join(', ')}"
      
      to_remove.each do |symbol|
        crypto = Cryptocurrency.find_by(symbol: symbol)
        if crypto
          # Lösche auch zugehörige historische Daten
          CryptoHistoryData.where(cryptocurrency: crypto).delete_all
          Indicator.where(cryptocurrency: crypto).delete_all
          
          crypto.destroy
          puts "✅ #{symbol} und zugehörige Daten entfernt"
        end
      end
    else
      puts "\n✅ Keine zu entfernenden Kryptowährungen gefunden"
    end
    
    # Finde fehlende Kryptowährungen (in Whitelist aber nicht in DB)
    current_cryptos_after_removal = Cryptocurrency.pluck(:symbol)
    to_add = whitelist - current_cryptos_after_removal
    
    if to_add.any?
      puts "\n➕ Füge fehlende Kryptowährungen hinzu: #{to_add.join(', ')}"
      
      to_add.each do |pair|
        begin
          # Konvertiere Pair-Format (z.B. "BTC/USDC" -> "BTCUSDC")
          symbol = pair.gsub('/', '').upcase
          
          puts "\n📈 Lade Daten für #{pair} (#{symbol})..."
          
          # Hole aktuellen Preis von Binance API
          price_data = fetch_binance_price(symbol)
          
          if price_data
            # Erstelle neue Kryptowährung in der Datenbank
            crypto = Cryptocurrency.new(
              symbol: pair,
              name: get_coin_name(symbol),
              current_price: price_data['price'].to_f,
              market_cap: price_data['market_cap'] || 0,
              market_cap_rank: price_data['market_cap_rank'] || 9999,
              price_change_percentage_24h: price_data['price_change_percentage_24h'] || 0,
              volume_24h: price_data['volume_24h'] || 0,
              last_updated: Time.current
            )
            
            if crypto.save
              puts "✅ #{pair} erfolgreich hinzugefügt - Preis: $#{price_data['price']}"
            else
              puts "❌ Fehler beim Speichern von #{pair}: #{crypto.errors.full_messages.join(', ')}"
            end
          else
            puts "[!] Keine Preisdaten für #{pair} gefunden"
          end
          
          # Kurze Pause zwischen API-Aufrufen
          sleep(0.1)
          
        rescue => e
          puts "❌ Fehler bei #{pair}: #{e.message}"
        end
      end
    else
      puts "\n✅ Keine fehlenden Kryptowährungen gefunden"
    end
    
    # Finale Synchronisation: Aktualisiere alle vorhandenen Kryptowährungen
    puts "\n[REFRESH] Aktualisiere alle vorhandenen Kryptowährungen..."
    
    Cryptocurrency.where(symbol: whitelist).each do |crypto|
      begin
        symbol = crypto.symbol.gsub('/', '').upcase
        price_data = fetch_binance_price(symbol)
        
        if price_data
          crypto.update!(
            current_price: price_data['price'].to_f,
            market_cap: price_data['market_cap'] || crypto.market_cap,
            market_cap_rank: price_data['market_cap_rank'] || crypto.market_cap_rank,
            price_change_percentage_24h: price_data['price_change_percentage_24h'] || 0,
            volume_24h: price_data['volume_24h'] || crypto.volume_24h,
            last_updated: Time.current
          )
          puts "✅ #{crypto.symbol} aktualisiert - Preis: $#{price_data['price']}"
        end
        
        sleep(0.1)
      rescue => e
        puts "❌ Fehler beim Aktualisieren von #{crypto.symbol}: #{e.message}"
      end
    end
    
    puts "\n🎉 Synchronisation abgeschlossen!"
    puts "📊 Finale Datenbankstatistik:"
    puts "  Gesamte Kryptowährungen: #{Cryptocurrency.count}"
    puts "  Whitelist-Paare: #{whitelist.length}"
    puts "  Aktuelle Kryptowährungen: #{Cryptocurrency.pluck(:symbol).join(', ')}"
  end
  
  private
  
  def self.fetch_binance_price(symbol)
    begin
      # Binance API für aktuellen Preis
      uri = URI("https://api.binance.com/api/v3/ticker/24hr?symbol=#{symbol}")
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        
        # Berechne geschätztes Market Cap (falls nicht verfügbar)
        price = data['lastPrice'].to_f
        volume_24h = data['volume'].to_f * price
        
        # Versuche Market Cap von CoinGecko zu holen
        market_cap_data = fetch_market_cap_from_coingecko(symbol)
        
        return {
          'price' => price,
          'volume_24h' => volume_24h,
          'price_change_percentage_24h' => data['priceChangePercent'].to_f,
          'market_cap' => market_cap_data['market_cap'],
          'market_cap_rank' => market_cap_data['market_cap_rank']
        }
      else
        puts "[!] Binance API Fehler für #{symbol}: #{response.code}"
        return nil
      end
    rescue => e
      puts "❌ Fehler beim Laden von #{symbol}: #{e.message}"
      return nil
    end
  end
  
  def self.fetch_market_cap_from_coingecko(symbol)
    begin
      # Konvertiere Binance-Symbol zu CoinGecko-ID
      coin_id = convert_to_coingecko_id(symbol)
      
      if coin_id
        uri = URI("https://api.coingecko.com/api/v3/coins/#{coin_id}")
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          data = JSON.parse(response.body)
          return {
            'market_cap' => data.dig('market_data', 'market_cap', 'usd') || 0,
            'market_cap_rank' => data.dig('market_cap_rank') || 9999
          }
        end
      end
    rescue => e
      puts "[!] CoinGecko API Fehler für #{symbol}: #{e.message}"
    end
    
    return { 'market_cap' => 0, 'market_cap_rank' => 9999 }
  end
  
  def self.convert_to_coingecko_id(symbol)
    # Mapping von Binance-Symbolen zu CoinGecko-IDs
    mapping = {
      'BTCUSDC' => 'bitcoin',
      'ETHUSDC' => 'ethereum',
      'BNBUSDC' => 'binancecoin',
      'ADAUSDC' => 'cardano',
      'SOLUSDC' => 'solana',
      'NEWTUSDC' => 'newton-project' # Beispiel - ersetzen Sie durch die korrekte CoinGecko-ID
    }
    
    mapping[symbol]
  end
  
  def self.get_coin_name(symbol)
    # Mapping von Symbolen zu Namen
    mapping = {
      'BTCUSDC' => 'Bitcoin',
      'ETHUSDC' => 'Ethereum',
      'BNBUSDC' => 'Binance Coin',
      'ADAUSDC' => 'Cardano',
      'SOLUSDC' => 'Solana',
      'NEWTUSDC' => 'Newton Project'
    }
    
    mapping[symbol] || symbol.gsub('USDC', '')
  end
end 