# Scheduler für regelmäßige Kryptowährungs-Updates
# DEAKTIVIERT: Verursacht möglicherweise doppelte Einträge
if Rails.env.development? || Rails.env.production?
  Rails.application.config.after_initialize do
    # DEAKTIVIERT - Scheduler wird manuell gestartet
    Rails.logger.info "🚀 Scheduler Initializer DEAKTIVIERT - Scheduler wird manuell gestartet"
    
    # KEIN AUTOMATISCHER START MEHR
    # Thread.new do
    #   loop do
    #     begin
    #       Rails.logger.info "Scheduled cryptocurrency update starting..."
    #       CryptocurrencyUpdateJob.perform_later
    #       
    #       # Warte für das konfigurierte Intervall
    #       sleep Rails.application.config.crypto_update_interval
    #     rescue => e
    #       Rails.logger.error "Scheduler error: #{e.message}"
    #       sleep 60 # Bei Fehler 1 Minute warten
    #     end
    #   end
    # end
  end
end 