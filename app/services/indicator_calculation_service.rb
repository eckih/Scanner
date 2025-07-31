class IndicatorCalculationService
  def self.calculate_and_save_rsi(cryptocurrency, timeframe = '15m', period = 14)
    Rails.logger.info "📊 Berechne RSI für #{cryptocurrency.symbol} (Timeframe: #{timeframe}, Periode: #{period})"
    
    # Hole historische Daten für RSI-Berechnung
    historical_data = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      interval: timeframe
    ).order(timestamp: :desc).limit(period + 1)
    
    if historical_data.count < period + 1
      Rails.logger.warn "[!] Nicht genügend Daten für RSI-Berechnung: #{historical_data.count} von #{period + 1} benötigt"
      return nil
    end
    
    # Extrahiere Close-Preise und sortiere chronologisch
    close_prices = historical_data.reverse.pluck(:close_price)
    
    # Berechne RSI
    rsi_value = calculate_rsi_from_prices(close_prices, period)
    
    if rsi_value
      Rails.logger.info "✅ RSI berechnet für #{cryptocurrency.symbol}: #{rsi_value.round(2)}"
      
      # Speichere in indicators Tabelle
      save_indicator(cryptocurrency, 'rsi', rsi_value, timeframe, period)
      
      # Broadcaste Update
      broadcast_indicator_update(cryptocurrency, 'rsi', rsi_value, timeframe, period)
      
      return rsi_value.round(2)
    else
      Rails.logger.error "❌ RSI-Berechnung fehlgeschlagen für #{cryptocurrency.symbol}"
      return nil
    end
  end
  
  def self.calculate_and_save_roc(cryptocurrency, timeframe = '15m', period = 14)
    Rails.logger.info "📊 Berechne ROC für #{cryptocurrency.symbol} (Timeframe: #{timeframe}, Periode: #{period})"
    
    # Hole historische Daten für ROC-Berechnung
    historical_data = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      interval: timeframe
    ).order(timestamp: :desc).limit(period + 1)
    
    if historical_data.count < period + 1
      Rails.logger.warn "[!] Nicht genügend Daten für ROC-Berechnung: #{historical_data.count} von #{period + 1} benötigt"
      return nil
    end
    
    # Berechne ROC
    close_prices = historical_data.reverse.pluck(:close_price)
    roc_value = calculate_roc_from_prices(close_prices, period)
    
    if roc_value
      Rails.logger.info "✅ ROC berechnet für #{cryptocurrency.symbol}: #{roc_value.round(2)}%"
      
      # Speichere in indicators Tabelle
      save_indicator(cryptocurrency, 'roc', roc_value, timeframe, period)
      
      # Broadcaste Update
      broadcast_indicator_update(cryptocurrency, 'roc', roc_value, timeframe, period)
      
      return roc_value.round(2)
    else
      Rails.logger.error "❌ ROC-Berechnung fehlgeschlagen für #{cryptocurrency.symbol}"
      return nil
    end
  end
  
  def self.calculate_and_save_roc_derivative(cryptocurrency, timeframe = '15m', period = 14)
    Rails.logger.info "📊 Berechne ROC Derivative für #{cryptocurrency.symbol} (Timeframe: #{timeframe}, Periode: #{period})"
    
    # Hole historische Daten für ROC Derivative
    historical_data = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      interval: timeframe
    ).order(timestamp: :desc).limit(period + 2)
    
    if historical_data.count < period + 2
      Rails.logger.warn "[!] Nicht genügend Daten für ROC Derivative: #{historical_data.count} von #{period + 2} benötigt"
      return nil
    end
    
    # Berechne ROC Derivative
    close_prices = historical_data.reverse.pluck(:close_price)
    roc_derivative_value = calculate_roc_derivative_from_prices(close_prices, period)
    
    if roc_derivative_value
      Rails.logger.info "✅ ROC Derivative berechnet für #{cryptocurrency.symbol}: #{roc_derivative_value.round(2)}"
      
      # Speichere in indicators Tabelle
      save_indicator(cryptocurrency, 'roc_derivative', roc_derivative_value, timeframe, period)
      
      # Broadcaste Update
      broadcast_indicator_update(cryptocurrency, 'roc_derivative', roc_derivative_value, timeframe, period)
      
      return roc_derivative_value.round(2)
    else
      Rails.logger.error "❌ ROC Derivative-Berechnung fehlgeschlagen für #{cryptocurrency.symbol}"
      return nil
    end
  end
  
  # Berechne alle Indikatoren für eine Kryptowährung
  def self.calculate_all_indicators(cryptocurrency, timeframe = '15m', period = 14)
    Rails.logger.info "📊 Berechne alle Indikatoren für #{cryptocurrency.symbol}"
    
    results = {}
    
    # RSI
    rsi_result = calculate_and_save_rsi(cryptocurrency, timeframe, period)
    results[:rsi] = rsi_result
    
    # ROC
    roc_result = calculate_and_save_roc(cryptocurrency, timeframe, period)
    results[:roc] = roc_result
    
    # ROC Derivative
    roc_derivative_result = calculate_and_save_roc_derivative(cryptocurrency, timeframe, period)
    results[:roc_derivative] = roc_derivative_result
    
    Rails.logger.info "✅ Alle Indikatoren berechnet für #{cryptocurrency.symbol}: #{results}"
    return results
  end
  
  private
  
  def self.calculate_rsi_from_prices(prices, period)
    return nil if prices.length < period + 1
    
    # Berechne Preisänderungen
    changes = []
    (1...prices.length).each do |i|
      changes << prices[i] - prices[i-1]
    end
    
    # Verwende nur die letzten 'period' Änderungen
    recent_changes = changes.last(period)
    
    # Trenne Gewinne und Verluste
    gains = recent_changes.map { |change| change > 0 ? change : 0 }
    losses = recent_changes.map { |change| change < 0 ? change.abs : 0 }
    
    # Berechne durchschnittliche Gewinne und Verluste
    avg_gain = gains.sum.to_f / period
    avg_loss = losses.sum.to_f / period
    
    # Vermeide Division durch Null
    return 50.0 if avg_loss == 0
    
    # Berechne RSI
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    # Begrenze RSI auf 0-100
    rsi = [0, [100, rsi].min].max
    
    rsi
  end
  
  def self.calculate_roc_from_prices(prices, period)
    return nil if prices.length < period + 1
    
    current_price = prices.last
    past_price = prices[prices.length - period - 1]
    
    return nil if past_price == 0
    
    roc = ((current_price - past_price) / past_price) * 100
    roc
  end
  
  def self.calculate_roc_derivative_from_prices(prices, period)
    return nil if prices.length < period + 2
    
    # Berechne ROC für aktuelle und vorherige Periode
    current_roc = calculate_roc_from_prices(prices, period)
    previous_prices = prices[0...-1]
    previous_roc = calculate_roc_from_prices(previous_prices, period)
    
    return nil if current_roc.nil? || previous_roc.nil?
    
    # ROC Derivative ist die Änderung des ROC
    roc_derivative = current_roc - previous_roc
    roc_derivative
  end
  
  def self.save_indicator(cryptocurrency, indicator_type, value, timeframe, period)
    # Prüfe ob bereits ein Indikator für diesen Zeitpunkt existiert
    existing_indicator = Indicator.where(
      cryptocurrency: cryptocurrency,
      indicator_type: indicator_type,
      timeframe: timeframe,
      period: period,
      calculated_at: Time.current
    ).first
    
    unless existing_indicator
      Indicator.create!(
        cryptocurrency: cryptocurrency,
        indicator_type: indicator_type,
        timeframe: timeframe,
        period: period,
        value: value,
        calculated_at: Time.current
      )
      Rails.logger.debug "📊 #{indicator_type.upcase} gespeichert für #{cryptocurrency.symbol}"
    end
  rescue => e
    Rails.logger.error "❌ Fehler beim Speichern des #{indicator_type.upcase}: #{e.message}"
  end
  
  def self.broadcast_indicator_update(cryptocurrency, indicator_type, value, timeframe, period)
    begin
      ActionCable.server.broadcast("prices", {
        cryptocurrency_id: cryptocurrency.id,
        symbol: cryptocurrency.symbol,
        indicator_type: indicator_type,
        value: value.round(4),
        timeframe: timeframe,
        period: period,
        timestamp: Time.now.iso8601,
        update_type: 'indicator'
      })
      
      Rails.logger.info "📡 #{indicator_type.upcase}-Update gebroadcastet für #{cryptocurrency.symbol}: #{value} (#{timeframe})"
    rescue => e
      Rails.logger.error "❌ Fehler beim #{indicator_type.upcase}-Broadcast: #{e.message}"
    end
  end
end 