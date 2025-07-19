class CryptoHistoryDatum < ApplicationRecord
  belongs_to :cryptocurrency
  
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :volume, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :timestamp, presence: true
end 