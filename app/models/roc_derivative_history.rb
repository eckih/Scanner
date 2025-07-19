class RocDerivativeHistory < ApplicationRecord
  belongs_to :cryptocurrency
  
  validates :derivative_value, presence: true, numericality: true
  validates :timestamp, presence: true
  
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_cryptocurrency, ->(crypto_id) { where(cryptocurrency_id: crypto_id) }
end 