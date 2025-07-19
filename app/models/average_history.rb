class AverageHistory < ApplicationRecord
  validates :rsi_average, presence: true, numericality: true
  validates :roc_average, presence: true, numericality: true
  validates :roc_derivative_average, presence: true, numericality: true
  validates :created_at, presence: true
end 