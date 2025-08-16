class RsiCalculationService
  def self.calculate_rsi_for_cryptocurrency(cryptocurrency, timeframe = '1m', period = 14)
    Rails.logger.info "📊 Berechne RSI für #{cryptocurrency.symbol} (Timeframe: #{timeframe}, Periode: #{period})"
    
    # Hole die letzten period+1 abgeschlossenen Kerzen für RSI-Berechnung
    # (Für 14 Änderungen brauchen wir 15 Kerzen)
    historical_data = CryptoHistoryData.where(
      cryptocurrency: cryptocurrency,
      interval: timeframe
    ).order(timestamp: :desc).limit(period + 1) # Neueste zuerst, period+1 Kerzen
    
    if historical_data.count < period + 1
      Rails.logger.warn "[!] Nicht genügend Daten für RSI-Berechnung: #{historical_data.count} von #{period + 1} benötigt"
      return nil
    end
    
    # Extrahiere Close-Preise und sortiere chronologisch (älteste zuerst)
    close_prices = historical_data.reverse.pluck(:close_price)
    
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
    return nil if prices.length < period + 1
    
    # Berechne Preisänderungen zwischen aufeinanderfolgenden Close-Preisen
    changes = []
    (1...prices.length).each do |i|
      changes << prices[i] - prices[i-1]
    end
    
    # Verwende nur die letzten 'period' Änderungen für RSI-Berechnung
    recent_changes = changes.last(period)
    
    # Trenne Gewinne und Verluste
    gains = recent_changes.map { |change| change > 0 ? change : 0 }
    losses = recent_changes.map { |change| change < 0 ? change.abs : 0 }
    
    # Berechne durchschnittliche Gewinne und Verluste für die Periode
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
  
  def self.save_rsi_history(cryptocurrency, rsi_value, timeframe)
    # Prüfe ob bereits ein RSI-Historie-Eintrag für diesen Zeitpunkt existiert
    existing_history = RsiHistory.where(
      cryptocurrency: cryptocurrency,
      timeframe: timeframe,
      calculated_at: Time.current
    ).first
    
    unless existing_history
      RsiHistory.create!(
        cryptocurrency: cryptocurrency,
        rsi_value: rsi_value,
        period: 14, # Standard-Periode
        timeframe: timeframe,
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
      # Berechne ROC-Formel (ROC × (1 + ROC'))
      roc_formula = calculate_roc_formula(cryptocurrency)
      
      # Berechne Summen für alle Kryptowährungen
      sums = calculate_column_sums
      
      ActionCable.server.broadcast("prices", {
        cryptocurrency_id: cryptocurrency.id,
        symbol: cryptocurrency.symbol,
        rsi: rsi_value,
        timeframe: timeframe,
        timestamp: Time.now.iso8601,
        update_type: 'rsi',
        roc_formula: roc_formula,
        column_sums: sums
      })
      
      Rails.logger.info "📡 RSI-Update gebroadcastet für #{cryptocurrency.symbol}: #{rsi_value} (#{timeframe}) mit ROC-Formel: #{roc_formula[:value]}"
    rescue => e
      Rails.logger.error "❌ Fehler beim RSI-Broadcast: #{e.message}"
    end
  end
  
  # Berechnet erweiterte ROC-Formel (ROC × (1 + ROC') × (1 + 1h_Änderung) × (1 + 30min_Änderung))
  def self.calculate_roc_formula(cryptocurrency)
    begin
      roc_value = cryptocurrency.current_roc('1m')
      roc_derivative_value = cryptocurrency.current_roc_derivative('1m')
      
      # Berechne 1h und 30min Änderungen
      price_changes = calculate_price_changes(cryptocurrency, cryptocurrency.current_price || 0)
      
      if roc_value && roc_derivative_value
        # Basis-Formel: ROC × (1 + ROC')
        base_formula = roc_value * (1 + roc_derivative_value)
        
        # Erweiterte Formel mit 1h und 30min Änderungen
        formula_value = base_formula
        
        # Multipliziere mit (1 + 1h_Änderung) wenn Daten verfügbar
        if price_changes[:has_1h_data] && price_changes[:change_1h]
          change_1h_decimal = price_changes[:change_1h] / 100.0  # Konvertiere % zu Dezimal
          formula_value *= (1 + change_1h_decimal)
        end
        
        # Multipliziere mit (1 + 30min_Änderung) wenn Daten verfügbar
        if price_changes[:has_30min_data] && price_changes[:change_30min]
          change_30min_decimal = price_changes[:change_30min] / 100.0  # Konvertiere % zu Dezimal
          formula_value *= (1 + change_30min_decimal)
        end
        
        {
          value: formula_value.round(2),
          roc: roc_value.round(2),
          roc_derivative: roc_derivative_value.round(2),
          change_1h: price_changes[:change_1h] || 0.0,
          change_30min: price_changes[:change_30min] || 0.0,
          has_1h_data: price_changes[:has_1h_data],
          has_30min_data: price_changes[:has_30min_data],
          has_data: true
        }
      else
        {
          value: 0.0,
          roc: roc_value || 0.0,
          roc_derivative: roc_derivative_value || 0.0,
          change_1h: price_changes[:change_1h] || 0.0,
          change_30min: price_changes[:change_30min] || 0.0,
          has_1h_data: price_changes[:has_1h_data],
          has_30min_data: price_changes[:has_30min_data],
          has_data: false
        }
      end
    rescue => e
      Rails.logger.error "❌ Fehler bei ROC-Formel-Berechnung für #{cryptocurrency.symbol}: #{e.message}"
      {
        value: 0.0,
        roc: 0.0,
        roc_derivative: 0.0,
        change_1h: 0.0,
        change_30min: 0.0,
        has_1h_data: false,
        has_30min_data: false,
        has_data: false
      }
    end
  end
  
  # Hilfsmethode für Preisänderungs-Berechnung
  def self.calculate_price_changes(cryptocurrency, current_price)
    begin
      changes = {
        change_24h: 0.0,
        change_1h: 0.0,
        change_30min: 0.0,
        has_24h_data: false,
        has_1h_data: false,
        has_30min_data: false
      }
      
      # 1h Änderung
      one_hour_ago = Time.now - 1.hour
      historical_data_1h = CryptoHistoryData.where(
        cryptocurrency: cryptocurrency,
        timestamp: ..one_hour_ago,
        interval: '1m'
      ).order(:timestamp).last
      
      if historical_data_1h
        old_price_1h = historical_data_1h.close_price
        changes[:change_1h] = ((current_price - old_price_1h) / old_price_1h) * 100
        changes[:has_1h_data] = true
      end
      
      # 30min Änderung
      thirty_minutes_ago = Time.now - 30.minutes
      historical_data_30min = CryptoHistoryData.where(
        cryptocurrency: cryptocurrency,
        timestamp: ..thirty_minutes_ago,
        interval: '1m'
      ).order(:timestamp).last
      
      if historical_data_30min
        old_price_30min = historical_data_30min.close_price
        changes[:change_30min] = ((current_price - old_price_30min) / old_price_30min) * 100
        changes[:has_30min_data] = true
      end
      
      # Runde alle Werte auf 2 Dezimalstellen
      changes[:change_1h] = changes[:change_1h].round(2)
      changes[:change_30min] = changes[:change_30min].round(2)
      
      changes
    rescue => e
      Rails.logger.error "❌ Fehler bei Preisänderungs-Berechnung für #{cryptocurrency.symbol}: #{e.message}"
      {
        change_24h: 0.0,
        change_1h: 0.0,
        change_30min: 0.0,
        has_24h_data: false,
        has_1h_data: false,
        has_30min_data: false
      }
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
  
  # Berechnet Summen für alle Spalten (24h, 1h, 30min Änderungen)
  def self.calculate_column_sums
    begin
      # Lade alle Kryptowährungen aus der Whitelist
      config_path = File.join(Rails.root, 'config', 'bot.json')
      config = JSON.parse(File.read(config_path))
      whitelist = config.dig('exchange', 'pair_whitelist') || []
      
      cryptocurrencies = Cryptocurrency.where(symbol: whitelist)
      
      sum_24h = 0.0
      sum_1h = 0.0
      sum_30min = 0.0
      count_24h = 0
      count_1h = 0
      count_30min = 0
      
      cryptocurrencies.each do |crypto|
        # 24h Summe - verwende dynamische Berechnung
        change_24h = crypto.calculate_24h_change
        if change_24h && crypto.has_24h_data?
          sum_24h += change_24h
          count_24h += 1
        end
        
        # 1h Summe - verwende dynamische Berechnung
        change_1h = crypto.calculate_1h_change
        if change_1h && crypto.has_1h_data?
          sum_1h += change_1h
          count_1h += 1
        end
        
        # 30min Summe - verwende dynamische Berechnung
        change_30min = crypto.calculate_30min_change
        if change_30min && crypto.has_30min_data?
          sum_30min += change_30min
          count_30min += 1
        end
      end
      
      {
        sum_24h: count_24h > 0 ? sum_24h.round(2) : 0.0,
        sum_1h: count_1h > 0 ? sum_1h.round(2) : 0.0,
        sum_30min: count_30min > 0 ? sum_30min.round(2) : 0.0,
        count_24h: count_24h,
        count_1h: count_1h,
        count_30min: count_30min
      }
    rescue => e
      Rails.logger.error "❌ Fehler bei Summen-Berechnung: #{e.message}"
      {
        sum_24h: 0.0,
        sum_1h: 0.0,
        sum_30min: 0.0,
        count_24h: 0,
        count_1h: 0,
        count_30min: 0
      }
    end
  end
end 