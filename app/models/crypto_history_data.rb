class CryptoHistoryData < ApplicationRecord
  belongs_to :cryptocurrency
  
  validates :cryptocurrency_id, presence: true
  validates :timestamp, presence: true
  validates :interval, presence: true, inclusion: { in: %w[1h 4h 1d 5m] }
  
  scope :for_cryptocurrency, ->(crypto) { where(cryptocurrency: crypto) }
  scope :for_interval, ->(interval) { where(interval: interval) }
  scope :recent, ->(limit = 100) { order(timestamp: :desc).limit(limit) }
  scope :ordered_by_time, -> { order(:timestamp) }
  
  def self.record_data(cryptocurrency, data, interval = '1h')
    create!(
      cryptocurrency: cryptocurrency,
      timestamp: data[:timestamp],
      open_price: data[:open],
      high_price: data[:high],
      low_price: data[:low],
      close_price: data[:close],
      volume: data[:volume],
      rsi: data[:rsi],
      roc: data[:roc],
      roc_derivative: data[:roc_derivative],
      interval: interval
    )
  rescue ActiveRecord::RecordNotUnique => e
    # Wenn der Datensatz bereits existiert, überspringe ihn
    Rails.logger.debug "Duplicate record skipped: #{e.message}"
  end
  
  def self.get_previous_data(cryptocurrency, interval = '1h', count = 1)
    where(cryptocurrency: cryptocurrency, interval: interval)
      .order(timestamp: :desc)
      .limit(count)
  end
  
  def self.cleanup_old_data(keep_periods = 100)
    # Lösche alte Daten, behalte nur die neuesten Datensätze
    intervals = %w[1m 1h 4h 1d 5m]
    
    intervals.each do |interval|
      # Für jede Kryptowährung und jedes Intervall
      Cryptocurrency.find_each do |crypto|
        # Für 1m-Intervall 1440 Einträge behalten, sonst keep_periods
        limit = interval == '1m' ? 1440 : keep_periods
        # Finde die neuesten Datensätze
        latest_records = where(cryptocurrency: crypto, interval: interval)
                           .order(timestamp: :desc)
                           .limit(limit)
                           .pluck(:id)
        
        # Lösche alle anderen Datensätze
        where(cryptocurrency: crypto, interval: interval)
          .where.not(id: latest_records)
          .delete_all
      end
    end
  end
  
  def self.get_chart_data(cryptocurrency, interval = '1h', limit = 100)
    where(cryptocurrency: cryptocurrency, interval: interval)
      .order(:timestamp)
      .limit(limit)
      .pluck(:timestamp, :close_price, :rsi, :roc, :roc_derivative)
      .map do |timestamp, close, rsi, roc, roc_derivative|
        {
          timestamp: timestamp,
          close: close,
          rsi: rsi,
          roc: roc,
          roc_derivative: roc_derivative
        }
      end
  end
end 