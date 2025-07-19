class CryptocurrencyUpdateJob
  def self.perform_later
    # Führe den Job sofort aus (für einfache Implementierung)
    new.perform
  end

  def perform
    Rails.logger.info "Starting background cryptocurrency update..."
    
    begin
      # Verwende BinanceService direkt
      top_symbols = BinanceService.get_top_usdc_pairs
      BinanceService.fetch_specific_cryptos(top_symbols)
      
      Rails.logger.info "Background cryptocurrency update completed successfully"
    rescue => e
      Rails.logger.error "Background cryptocurrency update failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end 