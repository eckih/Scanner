require 'httparty'
require 'openssl'
require 'base64'

class BalanceService
  include HTTParty
  base_uri 'https://api.binance.com'

  def self.fetch_and_update_balances
    puts "Starting to fetch balance data from Binance..."
    
    # API-Schlüssel aus Umgebungsvariablen abrufen
    api_key = ENV['BINANCE_API_KEY']
    api_secret = ENV['BINANCE_API_SECRET']
    
    if api_key.blank? || api_secret.blank?
      raise "BINANCE_API_KEY and BINANCE_API_SECRET environment variables must be set!"
    end
    
    # Account Balance abrufen
    account_balances = get_account_balance(api_key, api_secret)
    return unless account_balances
    
    # Geschätzte Balance berechnen
    total_btc, non_zero_balances = calculate_estimated_balance_btc(account_balances)
    total_usd = calculate_estimated_balance_usd(total_btc)
    
    puts "Total BTC: #{total_btc}, Total USD: #{total_usd}"
    
    # Daten in der Datenbank speichern
    save_balance_data(non_zero_balances, total_btc, total_usd)
    
    puts "Balance data successfully updated!"
  end

  private

  def self.get_account_balance(api_key, api_secret)
    timestamp = (Time.current.to_f * 1000).to_i
    query_string = "timestamp=#{timestamp}"
    signature = create_signature(query_string, api_secret)
    
    headers = {
      'X-MBX-APIKEY' => api_key
    }
    
    response = get("/api/v3/account", 
                   query: { timestamp: timestamp, signature: signature },
                   headers: headers)
    
    if response.success?
      account_info = response.parsed_response
      return account_info['balances']
    else
      puts "Error fetching account balance: #{response.code} - #{response.message}"
      puts "Response: #{response.body}"
      return nil
    end
  rescue => e
    puts "Exception in get_account_balance: #{e.message}"
    return nil
  end

  def self.calculate_estimated_balance_btc(balances)
    # Alle Ticker-Preise abrufen
    prices = fetch_all_prices
    return [0.0, []] unless prices
    
    price_dict = prices.each_with_object({}) do |ticker, hash|
      hash[ticker['symbol']] = ticker['price'].to_f
    end
    
    total_btc = 0.0
    non_zero_balances = []
    
    balances.each do |balance|
      asset = balance['asset']
      free = balance['free'].to_f
      locked = balance['locked'].to_f
      total = free + locked
      
      next if total <= 0
      
      asset_btc_value = 0.0
      
      if asset == 'BTC'
        asset_btc_value = total
      elsif asset == 'USDT'
        # USDT zu BTC über BTCUSDT Preis
        btc_price = price_dict['BTCUSDT']
        asset_btc_value = btc_price > 0 ? total / btc_price : 0.0
      else
        # Versuche direktes Trading-Paar zu finden
        symbol_btc = "#{asset}BTC"
        symbol_usdt = "#{asset}USDT"
        
        if price_dict[symbol_btc]
          asset_btc_value = total * price_dict[symbol_btc]
        elsif price_dict[symbol_usdt]
          # Asset zu USDT, dann USDT zu BTC
          usdt_value = total * price_dict[symbol_usdt]
          btc_price = price_dict['BTCUSDT']
          asset_btc_value = btc_price > 0 ? usdt_value / btc_price : 0.0
        end
      end
      
      total_btc += asset_btc_value
      
      non_zero_balances << {
        asset: asset,
        free: free,
        locked: locked,
        total: total,
        btc_value: asset_btc_value
      }
    end
    
    [total_btc, non_zero_balances]
  end

  def self.calculate_estimated_balance_usd(total_btc)
    # BTC zu USD Preis abrufen
    response = get('/api/v3/ticker/price', query: { symbol: 'BTCUSDT' })
    
    if response.success?
      btc_price = response.parsed_response['price'].to_f
      return total_btc * btc_price
    else
      puts "Error fetching BTC price: #{response.code}"
      return 0.0
    end
  rescue => e
    puts "Exception in calculate_estimated_balance_usd: #{e.message}"
    return 0.0
  end

  def self.fetch_all_prices
    response = get('/api/v3/ticker/price')
    
    if response.success?
      return response.parsed_response
    else
      puts "Error fetching prices: #{response.code}"
      return nil
    end
  rescue => e
    puts "Exception in fetch_all_prices: #{e.message}"
    return nil
  end

  def self.save_balance_data(balances, total_btc, total_usd)
    # Gesamt-Balance speichern
    total_balance_amount = balances.sum { |b| b[:total] }
    
    Balance.create!(
      asset: 'TOTAL',
      total_balance: total_balance_amount,
      free_balance: balances.sum { |b| b[:free] },
      locked_balance: balances.sum { |b| b[:locked] },
      total_btc: total_btc,
      total_usd: total_usd
    )
    
    # Einzelne Assets speichern
    balances.each do |balance|
      next if balance[:total] <= 0
      
      usd_value = balance[:btc_value] * (total_usd / total_btc) if total_btc > 0
      
      Balance.create!(
        asset: balance[:asset],
        total_balance: balance[:total],
        free_balance: balance[:free],
        locked_balance: balance[:locked],
        total_btc: balance[:btc_value],
        total_usd: usd_value || 0.0
      )
    end
  end

  def self.create_signature(query_string, api_secret)
    OpenSSL::HMAC.hexdigest('sha256', api_secret, query_string)
  end
end 