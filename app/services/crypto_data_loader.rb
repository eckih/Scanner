class CryptoDataLoader
  def self.load_real_cryptocurrency_data
    Rails.logger.info "Loading real cryptocurrency data from Binance API..."
    
    begin
      # Verwende BinanceService um echte Daten zu laden
      top_symbols = BinanceService.get_top_usdc_pairs
      BinanceService.fetch_specific_cryptos(top_symbols)
      
      Rails.logger.info "Cryptocurrency data loaded successfully"
    rescue => e
      Rails.logger.error "Error loading cryptocurrency data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
end 