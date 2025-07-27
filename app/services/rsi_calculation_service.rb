class RsiCalculationService
  def self.calculate_rsi_for_cryptocurrency(cryptocurrency, timeframe = '1m', period = 14)
    Rails.logger.info "📊 Berechne RSI für #{cryptocurrency.symbol} (Timeframe: #{timeframe}, Periode: #{period})"
    
    # Hole die letzten 14 abgeschlossenen Kerzen für RSI-Berechnung
    historical_data = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      interval: timeframe
    ).order(:timestamp).limit(period) # Nur die letzten 14 Kerzen
    
    if historical_data.count < period
      Rails.logger.warn "⚠️ Nicht genügend Daten für RSI-Berechnung: #{historical_data.count} von #{period} benötigt"
      return nil
    end
    
    # Extrahiere Close-Preise
    close_prices = historical_data.pluck(:close_price)
    
    # Berechne RSI
    rsi_value = calculate_rsi_from_prices(close_prices, period)
    
    if rsi_value
      Rails.logger.info "✅ RSI berechnet für #{cryptocurrency.symbol}: #{rsi_value.round(2)}"
      
      # Speichere RSI in der Haupttabelle
      cryptocurrency.update!(rsi: rsi_value.round(2))
      
      # Speichere RSI-Historie
      save_rsi_history(cryptocurrency, rsi_value, timeframe)
      
      # Broadcaste RSI-Update über ActionCable
      broadcast_rsi_update(cryptocurrency, rsi_value.round(2), timeframe)
      
      return rsi_value.round(2)
    else
      Rails.logger.error "❌ RSI-Berechnung fehlgeschlagen für #{cryptocurrency.symbol}"
      return nil
    end
  end
  
  private
  
  def self.calculate_rsi_from_prices(prices, period)
    return nil if prices.length < period
    
    # Berechne Preisänderungen zwischen aufeinanderfolgenden Close-Preisen
    changes = []
    (1...prices.length).each do |i|
      changes << prices[i] - prices[i-1]
    end
    
    # Trenne Gewinne und Verluste
    gains = changes.map { |change| change > 0 ? change : 0 }
    losses = changes.map { |change| change < 0 ? change.abs : 0 }
    
    # Berechne durchschnittliche Gewinne und Verluste für die Periode
    # Verwende alle verfügbaren Änderungen (period-1 Änderungen für period Kerzen)
    avg_gain = gains.sum.to_f / gains.length
    avg_loss = losses.sum.to_f / losses.length
    
    # Vermeide Division durch Null
    return 50.0 if avg_loss == 0
    
    # Berechne RSI
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    # Begrenze RSI auf 0-100
    rsi = [0, [100, rsi].min].max
    
    rsi
  end
  
  def self.save_rsi_history(cryptocurrency, rsi_value, timeframe)
    # Prüfe ob bereits ein RSI-Historie-Eintrag für diesen Zeitpunkt existiert
    existing_history = RsiHistory.where(
      cryptocurrency: cryptocurrency,
      interval: timeframe,
      calculated_at: Time.current
    ).first
    
    unless existing_history
      RsiHistory.create!(
        cryptocurrency: cryptocurrency,
        value: rsi_value,
        interval: timeframe,
        calculated_at: Time.current
      )
      Rails.logger.debug "📊 RSI-Historie gespeichert für #{cryptocurrency.symbol}"
    end
  rescue => e
    Rails.logger.error "❌ Fehler beim Speichern der RSI-Historie: #{e.message}"
  end
  
  # Broadcaste RSI-Update über ActionCable
  def self.broadcast_rsi_update(cryptocurrency, rsi_value, timeframe)
    begin
      ActionCable.server.broadcast("prices", {
        cryptocurrency_id: cryptocurrency.id,
        symbol: cryptocurrency.symbol,
        rsi: rsi_value,
        timeframe: timeframe,
        timestamp: Time.now.iso8601,
        update_type: 'rsi'
      })
      
      Rails.logger.info "📡 RSI-Update gebroadcastet für #{cryptocurrency.symbol}: #{rsi_value} (#{timeframe})"
    rescue => e
      Rails.logger.error "❌ Fehler beim RSI-Broadcast: #{e.message}"
    end
  end
  
  # Berechne RSI für alle Kryptowährungen
  def self.calculate_rsi_for_all_cryptocurrencies(timeframe = '1m', period = 14)
    Rails.logger.info "📊 Starte RSI-Berechnung für alle Kryptowährungen (Timeframe: #{timeframe}, Periode: #{period})"
    
    Cryptocurrency.find_each do |crypto|
      begin
        calculate_rsi_for_cryptocurrency(crypto, timeframe, period)
      rescue => e
        Rails.logger.error "❌ Fehler bei RSI-Berechnung für #{crypto.symbol}: #{e.message}"
      end
    end
    
    Rails.logger.info "✅ RSI-Berechnung für alle Kryptowährungen abgeschlossen"
  end
end 