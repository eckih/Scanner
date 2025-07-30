# WebSocket Service Initializer
# Startet den Binance WebSocket Service automatisch beim Rails-Start

# AKTIVIERT: Automatischer Start beim Container-Start
Rails.application.config.after_initialize do
  # Nur in Development-Umgebung und wenn nicht bereits gestartet
  if Rails.env.development? && !defined?(@websocket_service_started)
    @websocket_service_started = true
    
    Rails.logger.info "🚀 WebSocket Service Initializer AKTIVIERT - automatischer Start"
    
    # Automatischer Start mit reparierter PairSelector Methode
    Thread.new do
      begin
        # Kurz warten, damit Rails vollständig geladen ist
        sleep 3
        
        # Lade die WebSocket Service Datei
        require_relative '../../bin/binance_websocket_service'
        
        Rails.logger.info "🔧 Starte WebSocket Service automatisch..."
        
        # Starte den Service
        start_binance_websocket_service
        Rails.logger.info "✅ Binance WebSocket Service erfolgreich gestartet"
      rescue => e
        Rails.logger.error "❌ Fehler beim automatischen Start des WebSocket Service: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end 