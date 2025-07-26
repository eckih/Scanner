class Cryptocurrency < ApplicationRecord
  validates :symbol, presence: true, uniqueness: true
  validates :name, presence: true
  validates :current_price, presence: true, numericality: { greater_than: 0 }
  validates :market_cap, presence: true, numericality: { greater_than: 0 }
  validates :market_cap_rank, presence: true, numericality: { greater_than: 0 }
  
  # Explizit roc-Attribut definieren
  attribute :roc, :decimal, default: nil
  attribute :roc_derivative, :decimal, default: nil
  
  # Beziehungen - temporär deaktiviert um Seeds-Fehler zu beheben
  has_many :crypto_history_data, class_name: 'CryptoHistoryDatum', dependent: :destroy
  has_many :rsi_histories, dependent: :destroy
  has_many :roc_histories, dependent: :destroy
  has_many :roc_derivative_histories, dependent: :destroy
  
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
    symbol.gsub('USDC', '')
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

  def roc_color_class
    return "roc-neutral" if roc.nil?
    
    if roc >= 5
      "roc-positive"
    elsif roc <= -5
      "roc-negative"
    else
      "roc-neutral"
    end
  end

  def roc_signal
    return "Neutral" if roc.nil?
    
    if roc >= 5
      "Positiv"
    elsif roc <= -5
      "Negativ"
    else
      "Neutral"
    end
  end

  def roc_formatted
    return "N/A" if roc.nil?
    
    sign = roc >= 0 ? "+" : ""
    "#{sign}#{roc}%"
  end

  def roc_derivative_color_class
    return "roc-derivative-neutral" if roc_derivative.nil?
    
    if roc_derivative >= 1
      "roc-derivative-positive"
    elsif roc_derivative <= -1
      "roc-derivative-negative"
    else
      "roc-derivative-neutral"
    end
  end

  def roc_derivative_signal
    return "Neutral" if roc_derivative.nil?
    
    if roc_derivative >= 1
      "Beschleunigung"
    elsif roc_derivative <= -1
      "Verlangsamung"
    else
      "Stabil"
    end
  end

  def roc_derivative_formatted
    return "N/A" if roc_derivative.nil?
    
    sign = roc_derivative >= 0 ? "+" : ""
    "#{sign}#{roc_derivative.round(2)}"
  end

  # Einfache Hilfsmethoden für Trend-Anzeige
  def has_rsi?
    rsi.present? && rsi > 0
  end

  def has_roc?
    roc.present? && roc != 0
  end

  def has_roc_derivative?
    roc_derivative.present? && roc_derivative != 0
  end
end 