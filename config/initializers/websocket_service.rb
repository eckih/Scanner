# WebSocket Service Initializer
# Startet den Binance WebSocket Service automatisch beim Rails-Start

# DEAKTIVIERT: Automatischer Start verursacht doppelte Einträge
# Der Service wird jetzt manuell gestartet
Rails.application.config.after_initialize do
  # Nur in Development-Umgebung und wenn nicht bereits gestartet
  if Rails.env.development? && !defined?(@websocket_service_started)
    @websocket_service_started = true
    
    Rails.logger.info "🚀 WebSocket Service Initializer DEAKTIVIERT - Service wird manuell gestartet"
    
    # KEIN AUTOMATISCHER START MEHR
    # Thread.new do
    #   begin
    #     # Lade die WebSocket Service Datei
    #     require_relative '../../bin/binance_websocket_service'
    #     
    #     # Starte den Service
    #     if start_binance_websocket_service
    #       Rails.logger.info "✅ Binance WebSocket Service erfolgreich gestartet"
    #     else
    #       Rails.logger.error "❌ Binance WebSocket Service konnte nicht gestartet werden"
    #     end
    #   rescue => e
    #     Rails.logger.error "❌ Fehler beim Starten des WebSocket Service: #{e.message}"
    #     Rails.logger.error e.backtrace.join("\n")
    #   end
    # end
  end
end 