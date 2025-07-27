class RsiCalculationJob < ApplicationJob
  queue_as :default

  def perform(timeframe = '1m', period = 14)
    Rails.logger.info "🚀 Starte RSI-Berechnung Job (Timeframe: #{timeframe}, Periode: #{period})"
    
    begin
      # Verwende den neuen RSI-Berechnungsservice
      RsiCalculationService.calculate_rsi_for_all_cryptocurrencies(timeframe, period)
      
      Rails.logger.info "✅ RSI-Berechnung Job erfolgreich abgeschlossen"
    rescue => e
      Rails.logger.error "❌ Fehler im RSI-Berechnung Job: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
end 