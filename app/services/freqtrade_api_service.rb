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
    crypto = Cryptocurrency.find_or_initialize_by(symbol: coin_data['symbol']&.upcase)
    
    crypto.assign_attributes(
      name: coin_data['name'],
      current_price: coin_data['current_price'],
      market_cap: coin_data['market_cap'],
      market_cap_rank: coin_data['market_cap_rank'],
      price_change_percentage_24h: coin_data['price_change_percentage_24h'],
      volume_24h: coin_data['total_volume'],
      last_updated: Time.current
    )
    
    if crypto.save
      Rails.logger.debug "Updated #{crypto.symbol}: #{crypto.name}"
    else
      Rails.logger.error "Failed to save #{coin_data['symbol']}: #{crypto.errors.full_messages}"
    end
  end
end 