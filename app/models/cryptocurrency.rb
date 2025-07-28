class Cryptocurrency < ApplicationRecord
  validates :symbol, presence: true, uniqueness: true
  validates :name, presence: true
  validates :current_price, presence: true, numericality: { greater_than: 0 }
  validates :market_cap, presence: true, numericality: { greater_than: 0 }
  validates :market_cap_rank, presence: true, numericality: { greater_than: 0 }
  
  # Beziehungen
  has_many :crypto_history_data, class_name: 'CryptoHistoryDatum', dependent: :destroy
  has_many :indicators, dependent: :destroy
  
  scope :top_50, -> { order(:market_cap_rank).limit(50) }
  scope :by_market_cap, -> { order(market_cap: :desc) }
  
  def self.refresh_from_api
    FreqtradeApiService.new.fetch_top_cryptocurrencies
  end
  
  def calculate_trends
    # Berechne Trends basierend auf aktuellen Werten
    # Für jetzt simulieren wir es
    @rsi_trend_icon = "bi-arrow-right text-muted"
    @roc_trend_icon = "bi-arrow-right text-muted"
    @roc_derivative_trend_icon = "bi-arrow-right text-muted"
  end
  
  def base_symbol
    symbol.gsub('/', '').gsub('USDC', '').gsub('USDT', '')
  end
  
  def display_name
    # Mapping von Symbolen zu echten Namen
    name_mapping = {
      'BTC/USDC' => 'Bitcoin',
      'ETH/USDC' => 'Ethereum', 
      'BNB/USDC' => 'Binance Coin',
      'ADA/USDC' => 'Cardano',
      'SOL/USDC' => 'Solana',
      'NEWT/USDC' => 'Newton Project'
    }
    
    name_mapping[symbol] || base_symbol
  end
  
  def trading_pair
    symbol
  end
  
  def price_change_percentage_24h_formatted
    return "0.00%" if price_change_percentage_24h.nil?
    
    percentage = price_change_percentage_24h.round(2)
    sign = percentage >= 0 ? "+" : ""
    "#{sign}#{percentage}%"
  end
  
  def price_change_24h_complete?
    price_change_24h_complete == true
  end
  
  def price_change_color_class
    return "text-muted" if price_change_percentage_24h.nil?
    
    price_change_percentage_24h >= 0 ? "text-success" : "text-danger"
  end
  
  def formatted_market_cap
    return "N/A" if market_cap.nil?
    
    if market_cap >= 1_000_000_000_000
      "#{(market_cap / 1_000_000_000_000.0).round(2)}T $"
    elsif market_cap >= 1_000_000_000
      "#{(market_cap / 1_000_000_000.0).round(2)}B $"
    elsif market_cap >= 1_000_000
      "#{(market_cap / 1_000_000.0).round(2)}M $"
    else
      "#{market_cap.round(2)} $"
    end
  end
  
  def formatted_current_price
    return "N/A" if current_price.nil?
    
    if current_price >= 1
      "$#{current_price.round(2)}"
    else
      "$#{current_price.round(6)}"
    end
  end

  def formatted_volume_24h
    return "N/A" if volume_24h.nil? || volume_24h == 0
    
    if volume_24h >= 1_000_000_000
      "#{(volume_24h / 1_000_000_000.0).round(2)}B $"
    elsif volume_24h >= 1_000_000
      "#{(volume_24h / 1_000_000.0).round(2)}M $"
    elsif volume_24h >= 1_000
      "#{(volume_24h / 1_000.0).round(2)}K $"
    else
      "#{volume_24h.round(2)} $"
    end
  end

  def rsi_color_class
    return "rsi-neutral" if rsi.nil?
    
    if rsi <= 30
      "rsi-oversold"
    elsif rsi >= 70
      "rsi-overbought"
    else
      "rsi-neutral"
    end
  end

  def rsi_signal
    return "Neutral" if rsi.nil?
    
    if rsi <= 30
      "Überverkauft"
    elsif rsi >= 70
      "Überkauft"
    else
      "Neutral"
    end
  end

  # Convenience methods für aktuelle Indikatoren
  def current_rsi(timeframe = '15m', period = 14)
    indicators.rsi.for_timeframe(timeframe).for_period(period).latest.first&.value || rsi
  end
  
  def current_roc(timeframe = '15m', period = 14)
    indicators.roc.for_timeframe(timeframe).for_period(period).latest.first&.value
  end
  
  def current_roc_derivative(timeframe = '15m', period = 14)
    indicators.roc_derivative.for_timeframe(timeframe).for_period(period).latest.first&.value
  end
  
  def rsi_history(timeframe = '15m', period = 14, limit = 100)
    indicators.rsi.for_timeframe(timeframe).for_period(period)
             .order(:calculated_at)
             .limit(limit)
             .pluck(:calculated_at, :value)
             .map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } }
  end
  
  def roc_history(timeframe = '15m', period = 14, limit = 100)
    indicators.roc.for_timeframe(timeframe).for_period(period)
             .order(:calculated_at)
             .limit(limit)
             .pluck(:calculated_at, :value)
             .map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } }
  end
  
  # Einfache Hilfsmethoden für Trend-Anzeige
  def has_rsi?
    rsi.present? && rsi > 0
  end
end 