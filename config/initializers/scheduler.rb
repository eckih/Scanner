# Scheduler für regelmäßige Kryptowährungs-Updates
if Rails.env.development? || Rails.env.production?
  Rails.application.config.after_initialize do
    # Starte den Update-Scheduler nach der App-Initialisierung
    Thread.new do
      loop do
        begin
          Rails.logger.info "Scheduled cryptocurrency update starting..."
          CryptocurrencyUpdateJob.perform_later
          
          # Warte für das konfigurierte Intervall
          sleep Rails.application.config.crypto_update_interval
        rescue => e
          Rails.logger.error "Scheduler error: #{e.message}"
          sleep 60 # Bei Fehler 1 Minute warten
        end
      end
    end
  end
end 