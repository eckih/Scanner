class CryptocurrencyUpdateJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting background cryptocurrency update..."
    
    begin
      # Lade die Kryptowährungsdaten im Hintergrund
      CryptoDataLoader.load_real_cryptocurrency_data
      Rails.logger.info "Background cryptocurrency update completed successfully"
    rescue => e
      Rails.logger.error "Background cryptocurrency update failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end 