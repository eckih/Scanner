class ColumnSum < ApplicationRecord
  # Validierungen
  validates :sum_24h, presence: true, numericality: true
  validates :sum_1h, presence: true, numericality: true
  validates :sum_30min, presence: true, numericality: true
  validates :count_24h, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :count_1h, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :count_30min, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :calculated_at, presence: true
  
  # Scopes für einfache Queries
  scope :recent, ->(hours = 24) { where(calculated_at: hours.hours.ago..Time.current) }
  scope :latest, -> { order(calculated_at: :desc) }
  scope :for_chart, ->(hours = 24) { recent(hours).order(:calculated_at) }
  
  # Convenience methods
  def self.latest_sum
    latest.first
  end
  
  def self.chart_data(hours = 24)
    for_chart(hours).map do |sum|
      {
        x: sum.calculated_at.to_i * 1000, # JavaScript Timestamp
        y_24h: sum.sum_24h,
        y_1h: sum.sum_1h,
        y_30min: sum.sum_30min
      }
    end
  end
  
  # Durchschnittswerte für die letzten N Einträge
  def self.average_24h(limit = 10)
    latest.limit(limit).average(:sum_24h)&.round(2) || 0.0
  end
  
  def self.average_1h(limit = 10)
    latest.limit(limit).average(:sum_1h)&.round(2) || 0.0
  end
  
  def self.average_30min(limit = 10)
    latest.limit(limit).average(:sum_30min)&.round(2) || 0.0
  end
end
