class BalanceUpdateJob
  def self.perform_later
    # Führe den Job sofort aus (für einfache Implementierung)
    # new.perform
  end

  def perform
    Rails.logger.info "Starting background balance update..."
    
    begin
      # Lade die Balance-Daten im Hintergrund
      BalanceLoader.load_balance_data
      Rails.logger.info "Background balance update completed successfully"
    rescue => e
      Rails.logger.error "Background balance update failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end 