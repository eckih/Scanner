class Balance < ApplicationRecord
  validates :asset, presence: true
  validates :total_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_btc, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_usd, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_asset, ->(asset) { where(asset: asset) }
  scope :with_balance, -> { where('total_balance > 0') }
  
  def self.latest_total_balance
    where(asset: 'TOTAL').order(created_at: :desc).first
  end
  
  def self.latest_by_asset(asset)
    where(asset: asset).order(created_at: :desc).first
  end
  
  def self.chart_data_for_asset(asset, hours = 24)
    time_range = hours.hours.ago..Time.current
    where(asset: asset, created_at: time_range)
      .order(:created_at)
      .select(:created_at, :total_usd, :total_btc, :total_balance)
  end
  
  def self.all_assets_with_balance
    with_balance.where.not(asset: 'TOTAL').distinct.pluck(:asset).sort
  end
  
  def formatted_balance
    if total_balance > 1000
      "#{(total_balance / 1000).round(2)}K"
    elsif total_balance > 1_000_000
      "#{(total_balance / 1_000_000).round(2)}M"
    else
      total_balance.round(8).to_s.sub(/\.?0+$/, '')
    end
  end
  
  def formatted_balance_detailed
    if total_balance > 0.01
      total_balance.round(2).to_s
    else
      total_balance.round(8).to_s.sub(/\.?0+$/, '')
    end
  end
  
  def formatted_free_balance_detailed
    if free_balance > 0.01
      free_balance.round(2).to_s
    else
      free_balance.round(8).to_s.sub(/\.?0+$/, '')
    end
  end
  
  def formatted_locked_balance_detailed
    if locked_balance > 0.01
      locked_balance.round(2).to_s
    else
      locked_balance.round(8).to_s.sub(/\.?0+$/, '')
    end
  end
  
  def formatted_usd
    "$#{total_usd.round(2)}"
  end
  
  def formatted_btc
    "#{total_btc.round(8)} BTC"
  end
end 