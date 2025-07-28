class Indicator < ApplicationRecord
  belongs_to :cryptocurrency
  
  # Validierungen
  validates :timeframe, presence: true, inclusion: { in: %w[1m 5m 15m 1h 4h 1d] }
  validates :indicator_type, presence: true, inclusion: { in: %w[rsi roc roc_derivative ma ema macd] }
  validates :period, presence: true, numericality: { greater_than: 0 }
  validates :value, presence: true, numericality: true
  validates :calculated_at, presence: true
  
  # Scopes für einfache Queries
  scope :rsi, -> { where(indicator_type: 'rsi') }
  scope :roc, -> { where(indicator_type: 'roc') }
  scope :roc_derivative, -> { where(indicator_type: 'roc_derivative') }
  scope :ma, -> { where(indicator_type: 'ma') }
  scope :ema, -> { where(indicator_type: 'ema') }
  scope :macd, -> { where(indicator_type: 'macd') }
  
  scope :for_timeframe, ->(tf) { where(timeframe: tf) }
  scope :for_period, ->(p) { where(period: p) }
  scope :latest, -> { order(calculated_at: :desc) }
  scope :recent, ->(hours = 24) { where(calculated_at: hours.hours.ago..Time.current) }
  
  # Convenience methods für aktuelle Indikatoren
  def self.latest_rsi(crypto_id, timeframe = '15m', period = 14)
    rsi.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period).latest.first
  end
  
  def self.latest_roc(crypto_id, timeframe = '15m', period = 14)
    roc.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period).latest.first
  end
  
  def self.latest_roc_derivative(crypto_id, timeframe = '15m', period = 14)
    roc_derivative.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period).latest.first
  end
  
  # Historie für Charts
  def self.rsi_history(crypto_id, timeframe = '15m', period = 14, limit = 100)
    rsi.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period)
       .order(:calculated_at)
       .limit(limit)
       .pluck(:calculated_at, :value)
       .map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } }
  end
  
  def self.roc_history(crypto_id, timeframe = '15m', period = 14, limit = 100)
    roc.where(cryptocurrency_id: crypto_id, timeframe: timeframe, period: period)
       .order(:calculated_at)
       .limit(limit)
       .pluck(:calculated_at, :value)
       .map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } }
  end
  
  # Farb-Klassen für Frontend
  def rsi_color_class
    return "rsi-neutral" if value.nil?
    
    if value <= 30
      "rsi-oversold"
    elsif value >= 70
      "rsi-overbought"
    else
      "rsi-neutral"
    end
  end
  
  def rsi_signal
    return "Neutral" if value.nil?
    
    if value <= 30
      "Überverkauft"
    elsif value >= 70
      "Überkauft"
    else
      "Neutral"
    end
  end
  
  # Formatted value für Anzeige
  def formatted_value
    case indicator_type
    when 'rsi'
      "#{value.round(2)}"
    when 'roc', 'roc_derivative'
      sign = value >= 0 ? "+" : ""
      "#{sign}#{value.round(2)}%"
    when 'ma', 'ema'
      "$#{value.round(4)}"
    else
      value.round(4).to_s
    end
  end
  
  # Hilfsmethoden
  def rsi?
    indicator_type == 'rsi'
  end
  
  def roc?
    indicator_type == 'roc'
  end
  
  def roc_derivative?
    indicator_type == 'roc_derivative'
  end
  
  def ma?
    indicator_type == 'ma'
  end
  
  def ema?
    indicator_type == 'ema'
  end
  
  def macd?
    indicator_type == 'macd'
  end
end 