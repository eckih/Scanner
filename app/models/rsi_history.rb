class RsiHistory < ApplicationRecord
  belongs_to :cryptocurrency
  
  validates :rsi_value, presence: true, numericality: { greater_than: 0, less_than: 100 }
  validates :timestamp, presence: true
  
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_cryptocurrency, ->(crypto_id) { where(cryptocurrency_id: crypto_id) }
end 