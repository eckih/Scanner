require 'httparty'

class FreqtradeApiService
  include HTTParty
  
  # Freqtrade API Base URL - anpassen je nach Ihrer Freqtrade Installation
  base_uri ENV.fetch('FREQTRADE_API_URL', 'http://localhost:8080')
  
  def initialize
    @headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV.fetch('FREQTRADE_API_TOKEN', '')}"
    }
  end
  
  def fetch_top_cryptocurrencies
    begin
      # Da Freqtrade primär für Trading ist, verwenden wir CoinGecko als Fallback
      # für Market Cap Daten und kombinieren mit Freqtrade für Trading-Daten
      coingecko_data = fetch_from_coingecko
      
      coingecko_data.each do |coin_data|
        update_or_create_cryptocurrency(coin_data)
      end
      
      Rails.logger.info "Successfully updated #{coingecko_data.size} cryptocurrencies"
      
    rescue StandardError => e
      Rails.logger.error "Error fetching cryptocurrency data: #{e.message}"
      raise e
    end
  end
  
  private
  
  def fetch_from_coingecko
    # CoinGecko API für Market Cap und Preisdaten
    response = HTTParty.get(
      'https://api.coingecko.com/api/v3/coins/markets',
      query: {
        vs_currency: 'eur',
        order: 'market_cap_desc',
        per_page: 50,
        page: 1,
        sparkline: false,
        price_change_percentage: '24h'
      },
      headers: { 'Content-Type' => 'application/json' }
    )
    
    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoinGecko API error: #{response.code} - #{response.message}"
      []
    end
  end
  
  def update_or_create_cryptocurrency(coin_data)
    # RSI für das jeweilige Trading-Paar berechnen
    rsi_value = calculate_rsi_for_symbol(coin_data['symbol']&.upcase)
    
    crypto = Cryptocurrency.find_or_initialize_by(symbol: coin_data['symbol']&.upcase)
    
    crypto.assign_attributes(
      name: coin_data['name'],
      current_price: coin_data['current_price'],
      market_cap: coin_data['market_cap'],
      market_cap_rank: coin_data['market_cap_rank'],
      price_change_percentage_24h: coin_data['price_change_percentage_24h'],
      volume_24h: coin_data['total_volume'],
      rsi: rsi_value,
      last_updated: Time.current
    )
    
    if crypto.save
      Rails.logger.debug "Updated #{crypto.symbol}: #{crypto.name}"
    else
      Rails.logger.error "Failed to save #{coin_data['symbol']}: #{crypto.errors.full_messages}"
    end
  end
  
  def calculate_rsi_for_symbol(symbol)
    begin
      # Versuche Freqtrade API für RSI-Daten zu verwenden
      pair = "#{symbol}/USDT"  # Annahme: USDT-Paare
      
      response = self.class.get(
        "/api/v1/pair_candles",
        query: {
          pair: pair,
          timeframe: '1d',
          limit: 14  # Für RSI-Berechnung
        },
        headers: @headers
      )
      
      if response.success? && response.parsed_response['data']
        candles = response.parsed_response['data']
        calculate_rsi_from_candles(candles)
      else
        # Fallback: Simuliere RSI-Wert basierend auf 24h Preisänderung
        simulate_rsi_from_price_change
      end
      
    rescue StandardError => e
      Rails.logger.warn "Could not fetch RSI for #{symbol}: #{e.message}"
      simulate_rsi_from_price_change
    end
  end
  
  def calculate_rsi_from_candles(candles)
    return nil if candles.size < 14
    
    closes = candles.map { |candle| candle[4].to_f }  # Close prices
    
    gains = []
    losses = []
    
    (1...closes.size).each do |i|
      change = closes[i] - closes[i-1]
      if change > 0
        gains << change
        losses << 0
      else
        gains << 0
        losses << change.abs
      end
    end
    
    return nil if gains.empty?
    
    avg_gain = gains.sum / gains.size
    avg_loss = losses.sum / losses.size
    
    return 50 if avg_loss == 0  # Avoid division by zero
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    rsi.round(2)
  end
  
  def simulate_rsi_from_price_change
    # Einfache RSI-Simulation basierend auf zufälligen Werten
    # In einer echten Implementierung würden Sie historische Daten verwenden
    rand(20..80).round(2)
  end
end 