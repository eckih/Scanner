class CryptocurrencyUpdateJob
  def self.perform_later
    # Führe den Job sofort aus (für einfache Implementierung)
    new.perform
  end

  def perform
    Rails.logger.info "Starting background cryptocurrency update..."
    
    begin
      # Temporär deaktiviert - BinanceService wurde entfernt
      Rails.logger.info "Background cryptocurrency update skipped - BinanceService removed"
    rescue => e
      Rails.logger.error "Background cryptocurrency update failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end 