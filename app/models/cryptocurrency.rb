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
  
  # Dynamische Berechnung der Preisänderungen aus historischen Daten
  def calculate_24h_change
    twenty_four_hours_ago = Time.now - 24.hours
    historical_data = crypto_history_data.where(
      timestamp: ..twenty_four_hours_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data && current_price
      old_price = historical_data.close_price
      ((current_price - old_price) / old_price) * 100
    else
      0.0
    end
  end
  
  def calculate_1h_change
    one_hour_ago = Time.now - 1.hour
    historical_data = crypto_history_data.where(
      timestamp: ..one_hour_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data && current_price
      old_price = historical_data.close_price
      ((current_price - old_price) / old_price) * 100
    else
      0.0
    end
  end
  
  def calculate_30min_change
    thirty_minutes_ago = Time.now - 30.minutes
    historical_data = crypto_history_data.where(
      timestamp: ..thirty_minutes_ago,
      interval: '1m'
    ).order(:timestamp).last
    
    if historical_data && current_price
      old_price = historical_data.close_price
      ((current_price - old_price) / old_price) * 100
    else
      0.0
    end
  end
  
  # Vollständigkeit der Daten prüfen
  def has_24h_data?
    twenty_four_hours_ago = Time.now - 24.hours
    crypto_history_data.where(
      timestamp: ..twenty_four_hours_ago,
      interval: '1m'
    ).exists?
  end
  
  def has_1h_data?
    one_hour_ago = Time.now - 1.hour
    crypto_history_data.where(
      timestamp: ..one_hour_ago,
      interval: '1m'
    ).exists?
  end
  
  def has_30min_data?
    thirty_minutes_ago = Time.now - 30.minutes
    crypto_history_data.where(
      timestamp: ..thirty_minutes_ago,
      interval: '1m'
    ).exists?
  end
  
  # Formatierte Ausgabe der dynamisch berechneten Werte
  def price_change_percentage_24h_formatted
    change = calculate_24h_change
    return "0.00%" if change == 0.0 && !has_24h_data?
    
    percentage = change.round(2)
    sign = percentage >= 0 ? "+" : ""
    "#{sign}#{percentage}%"
  end
  
  def price_change_percentage_1h_formatted
    change = calculate_1h_change
    return "0.00%" if change == 0.0 && !has_1h_data?
    
    percentage = change.round(2)
    sign = percentage >= 0 ? "+" : ""
    "#{sign}#{percentage}%"
  end
  
  def price_change_percentage_30min_formatted
    change = calculate_30min_change
    return "0.00%" if change == 0.0 && !has_30min_data?
    
    percentage = change.round(2)
    sign = percentage >= 0 ? "+" : ""
    "#{sign}#{percentage}%"
  end
  
  def price_change_24h_complete?
    has_24h_data?
  end
  
  def price_change_1h_complete?
    has_1h_data?
  end
  
  def price_change_30min_complete?
    has_30min_data?
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
    current_rsi_value = current_rsi
    return "rsi-neutral" if current_rsi_value.nil?
    
    if current_rsi_value <= 30
      "rsi-oversold"
    elsif current_rsi_value >= 70
      "rsi-overbought"
    else
      "rsi-neutral"
    end
  end

  def rsi_signal
    current_rsi_value = current_rsi
    return "Neutral" if current_rsi_value.nil?
    
    if current_rsi_value <= 30
      "Überverkauft"
    elsif current_rsi_value >= 70
      "Überkauft"
    else
      "Neutral"
    end
  end

  # Convenience methods für aktuelle Indikatoren
  def current_rsi(timeframe = '15m', period = 14)
    # Fallback auf Datenbank (Cache wird im WebSocket-Service verwaltet)
    indicators.rsi.for_timeframe(timeframe).for_period(period).latest.first&.value
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
    current_rsi.present?
  end
end 