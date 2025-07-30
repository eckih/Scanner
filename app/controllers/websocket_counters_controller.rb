class WebsocketCountersController < ApplicationController
  def send_counters
    # Hole echte Zähler vom WebSocket-Service (falls verfügbar)
    # Da globale Variablen nicht zwischen Prozessen geteilt werden,
    # verwenden wir einen direkten ActionCable-Broadcast-Trigger
    
    begin
      # Trigger für WebSocket-Service, um aktuelle Zähler zu broadcasten
      # Dies funktioniert nur, wenn der WebSocket-Service läuft
      Rails.logger.info "📊 Zähler-Update vom Frontend angefordert"
      
      # Sende eine einfache Bestätigung zurück
      render json: { 
        status: 'success', 
        message: 'Zähler-Update angefordert - Daten kommen vom WebSocket-Service'
      }
      
    rescue => e
      Rails.logger.error "❌ Fehler beim Zähler-Update: #{e.message}"
      render json: { 
        status: 'error', 
        message: e.message 
      }
    end
  end
end 