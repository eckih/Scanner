require_dependency "crypto_config"

class CryptocurrenciesController < ApplicationController
  ROC_PERIOD = 24 # Standard ROC-Periode in Stunden
  
  # CSRF-Schutz für AJAX-Endpoints deaktivieren
  skip_before_action :verify_authenticity_token, only: [:add_roc_derivative, :calculate_rsi, :update_rsi_settings]

  def index
    # Lade nur Kryptowährungen aus der bot.json Whitelist
    whitelist = load_whitelist_pairs
    @cryptocurrencies = Cryptocurrency.where(symbol: whitelist).order(:market_cap_rank)
    
    # @last_update entfernt - nicht mehr benötigt für Live-Updates
    calculate_trends_for_cryptocurrencies

    # Lade aktuelle Frontend-Einstellungen für RSI
    @current_timeframe = Rails.cache.read('frontend_selected_timeframe') || '1m'
    @current_rsi_period = Rails.cache.read('frontend_selected_rsi_period') || 14

    # Effizient: Hash mit den letzten Preisen für alle Cryptos (immer 1m für Echtzeit-Updates)
    subquery = CryptoHistoryData.select('MAX(timestamp) as max_time, cryptocurrency_id')
                                .where(interval: '1m')
                                .group(:cryptocurrency_id)
    
    @latest_prices = CryptoHistoryData.joins("INNER JOIN (#{subquery.to_sql}) sub ON crypto_history_data.cryptocurrency_id = sub.cryptocurrency_id AND crypto_history_data.timestamp = sub.max_time")
                                      .where(interval: '1m')
                                      .pluck(:cryptocurrency_id, :close_price)
                                      .to_h

    # Lade Mini-Candlestick-Daten für alle Cryptos
    @mini_candlestick_data = load_mini_candlestick_data(@cryptocurrencies, @current_timeframe)
    
    # Lade aktuelle 1h Kerzen für alle Cryptos
    @current_1h_candle_data = load_current_1h_candle_data(@cryptocurrencies)
    
    # Berechne Summen für 24h, 1h und 30min Änderungen
    @sum_24h_change = calculate_sum_24h_change(@cryptocurrencies)
    @sum_1h_change = calculate_sum_1h_change(@cryptocurrencies)
    @sum_30min_change = calculate_sum_30min_change(@cryptocurrencies)
  end

  def show
    @cryptocurrency = Cryptocurrency.find(params[:id])
    @chart_data = create_indicator_chart_data(@cryptocurrency, '15m', 14)
  end

  def settings
    @settings = CryptoConfig.settings
  end

  def update_settings
    if CryptoConfig.update_settings(settings_params)
      redirect_to settings_cryptocurrencies_path, notice: 'Einstellungen wurden aktualisiert.'
    else
      @settings = CryptoConfig.settings
      render :settings
    end
  end

  def add_roc_derivative
    # Starte Background-Job für ROC-Derivative-Berechnung
    CryptocurrencyUpdateJob.perform_later
    
    respond_to do |format|
      format.html { redirect_to cryptocurrencies_path, notice: 'ROC-Derivative-Berechnung wurde im Hintergrund gestartet.' }
      format.json { render json: { status: 'started', message: 'ROC-Derivative-Berechnung wurde im Hintergrund gestartet.' } }
    end
  end

  def averages_chart
    @cryptocurrencies = Cryptocurrency.all
    # Verwende die neue indicators Tabelle für Chart-Daten
    @chart_data = {
      rsi: Indicator.rsi.latest.limit(100).pluck(:calculated_at, :value).map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } },
      roc: Indicator.roc.latest.limit(100).pluck(:calculated_at, :value).map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } },
      roc_derivative: Indicator.roc_derivative.latest.limit(100).pluck(:calculated_at, :value).map { |timestamp, value| { x: timestamp.to_i * 1000, y: value } }
    }
  end

  def chart
    @cryptocurrency = Cryptocurrency.find(params[:id])
    @chart_data = create_indicator_chart_data(@cryptocurrency, '15m', 14)
  end

  def chart_data
    @cryptocurrency = Cryptocurrency.find(params[:id])
    @chart_data = create_indicator_chart_data(@cryptocurrency, '15m', 14)
    
    render json: @chart_data
  end

  def last_update
    begin
      last_rsi_update = Indicator.rsi.maximum(:calculated_at)
      last_roc_update = Indicator.roc.maximum(:calculated_at)
      last_roc_derivative_update = Indicator.roc_derivative.maximum(:calculated_at)
      last_update = [last_rsi_update, last_roc_update, last_roc_derivative_update].compact.max
      if last_update.nil?
        last_update = Cryptocurrency.maximum(:updated_at)
      end
      render json: {
        last_update: last_update ? last_update.iso8601 : nil,
        last_rsi_update: last_rsi_update ? last_rsi_update.iso8601 : nil,
        last_roc_update: last_roc_update ? last_roc_update.iso8601 : nil,
        last_roc_derivative_update: last_roc_derivative_update ? last_roc_derivative_update.iso8601 : nil
      }
    rescue => e
      Rails.logger.error("Fehler in last_update: #{e.class} - #{e.message}")
      render json: { error: e.message }, status: 500
    end    
  end

  def calculate_rsi
    timeframe = params[:timeframe] || '1m'
    period = (params[:period] || 14).to_i
    
    # Validiere Parameter
    valid_timeframes = ['1m', '5m', '15m', '1h', '4h', '1d']
    unless valid_timeframes.include?(timeframe)
      render json: { error: 'Ungültiger Timeframe' }, status: 400
      return
    end
    
    unless period.between?(1, 50)
      render json: { error: 'RSI-Periode muss zwischen 1 und 50 liegen' }, status: 400
      return
    end
    
    # Verwende den neuen IndicatorCalculationService
    results = {}
    
    Cryptocurrency.find_each do |crypto|
      rsi_value = IndicatorCalculationService.calculate_and_save_rsi(crypto, timeframe, period)
      results[crypto.symbol] = rsi_value
    end
    
    Rails.logger.info "🚀 RSI-Berechnung abgeschlossen (Timeframe: #{timeframe}, Periode: #{period})"
    
    render json: {
      success: true,
      message: "RSI-Berechnung abgeschlossen (Timeframe: #{timeframe}, Periode: #{period})",
      timeframe: timeframe,
      period: period,
      results: results
    }
  rescue => e
    Rails.logger.error "❌ Fehler beim Starten der RSI-Berechnung: #{e.message}"
    render json: { error: e.message }, status: 500
  end

  def update_rsi_settings
    timeframe = params[:timeframe] || '1m'
    period = (params[:period] || 14).to_i
    
    # Validiere Parameter
    valid_timeframes = ['1m', '5m', '15m', '1h', '4h', '1d']
    unless valid_timeframes.include?(timeframe)
      render json: { error: 'Ungültiger Timeframe' }, status: 400
      return
    end
    
    unless period.between?(1, 50)
      render json: { error: 'RSI-Periode muss zwischen 1 und 50 liegen' }, status: 400
      return
    end
    
    # Speichere Einstellungen im Rails-Cache für WebSocket-Service
    Rails.cache.write('frontend_selected_timeframe', timeframe, expires_in: 1.hour)
    Rails.cache.write('frontend_selected_rsi_period', period, expires_in: 1.hour)
    
    Rails.logger.info "⚙️ RSI-Einstellungen aktualisiert: Timeframe=#{timeframe}, Periode=#{period}"
    
    render json: {
      success: true,
      message: "RSI-Einstellungen aktualisiert (Timeframe: #{timeframe}, Periode: #{period})",
      timeframe: timeframe,
      period: period
    }
  rescue => e
    Rails.logger.error "❌ Fehler beim Aktualisieren der RSI-Einstellungen: #{e.message}"
    render json: { error: e.message }, status: 500
  end

  def mini_candlestick_data
    timeframe = params[:timeframe] || '1m'
    
    # Lade nur Kryptowährungen aus der bot.json Whitelist
    whitelist = load_whitelist_pairs
    cryptocurrencies = Cryptocurrency.where(symbol: whitelist)
    
    candlestick_data = load_mini_candlestick_data(cryptocurrencies, timeframe)
    
    render json: candlestick_data
  end

  def current_1h_candle_data
    # Lade nur Kryptowährungen aus der bot.json Whitelist
    whitelist = load_whitelist_pairs
    cryptocurrencies = Cryptocurrency.where(symbol: whitelist)
    
    current_candle_data = load_current_1h_candle_data(cryptocurrencies)
    
    render json: current_candle_data
  end

  private

  def settings_params
    params.require(:settings).permit(:rsi_period, :roc_period, :roc_derivative_period)
  end
  
  private
  
  def load_whitelist_pairs
    config_path = Rails.root.join('config', 'bot.json')
    return [] unless File.exist?(config_path)
    
    begin
      config = JSON.parse(File.read(config_path))
      config.dig('exchange', 'pair_whitelist') || []
    rescue => e
      Rails.logger.error "Fehler beim Laden der bot.json: #{e.message}"
      []
    end
  end

  def calculate_trends_for_cryptocurrencies
    @cryptocurrencies.each do |crypto|
      crypto.calculate_trends
    end
  end

  def create_chart_data(rsi_histories, roc_histories, roc_derivative_histories)
    {
      rsi: rsi_histories.map { |h| { x: h.created_at.to_i * 1000, y: h.value } },
      roc: roc_histories.map { |h| { x: h.created_at.to_i * 1000, y: h.value } },
      roc_derivative: roc_derivative_histories.map { |h| { x: h.created_at.to_i * 1000, y: h.value } }
    }
  end
  
  # Neue Methode für die indicators Tabelle
  def create_indicator_chart_data(cryptocurrency, timeframe = '15m', period = 14)
    {
      rsi: cryptocurrency.rsi_history(timeframe, period, 100),
      roc: cryptocurrency.roc_history(timeframe, period, 100),
      roc_derivative: [] # Noch nicht implementiert
    }
  end

  def load_mini_candlestick_data(cryptocurrencies, timeframe)
    candlestick_data = {}
    
    Rails.logger.info "🕯️ Lade Mini-Candlestick-Daten für #{cryptocurrencies.count} Cryptos mit Timeframe: #{timeframe}"
    
    # Berechne den Zeitbereich basierend auf dem Timeframe
    timeframe_minutes = case timeframe
                        when '1m' then 1
                        when '5m' then 5
                        when '15m' then 15
                        when '1h' then 60
                        when '4h' then 240
                        when '1d' then 1440
                        else 1
                        end
    
    cryptocurrencies.each do |crypto|
      Rails.logger.info "🕯️ Verarbeite Crypto: #{crypto.symbol} (ID: #{crypto.id})"
      
      # Hole die letzten 5 Kerzen für den gewählten Timeframe (immer die neuesten)
      candles_desc = CryptoHistoryData.where(cryptocurrency: crypto, interval: timeframe)
                                      .order(timestamp: :desc)
                                      .limit(5)
      candles = candles_desc.reverse # Chronologisch (älteste zuerst)
      
      Rails.logger.info "🕯️ Gefundene Kerzen für #{crypto.symbol}: #{candles.count}"
      
      if candles.any?
        candlestick_data[crypto.id] = candles.map do |candle|
          {
            open: candle.open_price.to_f,
            high: candle.high_price.to_f,
            low: candle.low_price.to_f,
            close: candle.close_price.to_f,
            timestamp: candle.timestamp,
            isGreen: candle.close_price > candle.open_price
          }
        end
      else
        # Fallback: Versuche andere Timeframes, aber nur wenn sie aktuell sind
        Rails.logger.warn "🕯️ Keine Daten für #{timeframe} gefunden, versuche andere Timeframes für #{crypto.symbol}"
        
        fallback_timeframes = ['1m', '5m', '15m', '1h'].reject { |tf| tf == timeframe }
        fallback_candles = nil
        
        fallback_timeframes.each do |fallback_tf|
          fallback_minutes = case fallback_tf
                            when '1m' then 1
                            when '5m' then 5
                            when '15m' then 15
                            when '1h' then 60
                            else 1
                            end
          
          fallback_range = (fallback_minutes * 3).minutes.ago
          fallback_candles = CryptoHistoryData.where(cryptocurrency: crypto, interval: fallback_tf)
                                            .where('timestamp >= ?', fallback_range)
                                            .order(timestamp: :asc)
                                            .limit(5)
          
          if fallback_candles.any?
            Rails.logger.info "🕯️ Fallback-Daten gefunden für #{crypto.symbol} mit Timeframe #{fallback_tf}: #{fallback_candles.count} Kerzen"
            break
          end
        end
        
        if fallback_candles&.any?
          # Nutze die letzten 5 Fallback-Kerzen (chronologisch)
          fallback_list = fallback_candles.sort_by(&:timestamp).last(5)
          candlestick_data[crypto.id] = fallback_list.map do |candle|
            {
              open: candle.open_price.to_f,
              high: candle.high_price.to_f,
              low: candle.low_price.to_f,
              close: candle.close_price.to_f,
              timestamp: candle.timestamp,
              isGreen: candle.close_price > candle.open_price
            }
          end
        else
          Rails.logger.warn "🕯️ Keine aktuellen Fallback-Daten gefunden für #{crypto.symbol}"
          candlestick_data[crypto.id] = []
        end
      end
      
      Rails.logger.info "🕯️ Verarbeitete Daten für #{crypto.symbol}: #{candlestick_data[crypto.id].length} Kerzen"
    end
    
    Rails.logger.info "🕯️ Gesamt Mini-Candlestick-Daten: #{candlestick_data.keys.length} Cryptos"
    candlestick_data
  end

  def load_current_1h_candle_data(cryptocurrencies)
    current_candle_data = {}
    
    Rails.logger.info "🕯️ Lade aktuelle 1h Kerzen für #{cryptocurrencies.count} Cryptos"
    
    cryptocurrencies.each do |crypto|
      Rails.logger.info "🕯️ Verarbeite aktuelle 1h Kerzen für: #{crypto.symbol} (ID: #{crypto.id})"
      
      # Finde die letzten 3 1h Kerzen
      current_hour_start = Time.now.beginning_of_hour
      current_hour_end = Time.now.end_of_hour
      
      # Suche nach den letzten 3 1h Kerzen (oder mehr, falls nicht genug vorhanden)
      recent_candles = CryptoHistoryData.where(cryptocurrency: crypto, interval: '1h')
                                       .order(timestamp: :desc)
                                       .limit(5)
      
      if recent_candles.any?
        Rails.logger.info "🕯️ #{recent_candles.count} 1h Kerzen gefunden für #{crypto.symbol}"
        
        # Konvertiere zu Array und sortiere chronologisch (älteste zuerst)
        candles_array = recent_candles.reverse.map do |candle|
          # Prüfe ob die Kerze für die aktuelle Stunde ist
          is_current_hour = candle.timestamp >= current_hour_start && candle.timestamp <= current_hour_end
          is_complete = Time.now >= current_hour_end && is_current_hour
          
          {
            open: candle.open_price.to_f,
            high: candle.high_price.to_f,
            low: candle.low_price.to_f,
            close: candle.close_price.to_f,
            timestamp: candle.timestamp,
            isGreen: candle.close_price > candle.open_price,
            isComplete: is_complete,
            isCurrentHour: is_current_hour
          }
        end
        
        # Verwende nur die letzten 3 Kerzen
        candles_array = candles_array.last(3)
        
        current_candle_data[crypto.id] = candles_array
        
        Rails.logger.info "🕯️ 1h Kerzen Details für #{crypto.symbol}: #{candles_array.length} Kerzen"
        candles_array.each_with_index do |candle, index|
          Rails.logger.info "🕯️ Kerze #{index + 1}: O:#{candle[:open]} H:#{candle[:high]} L:#{candle[:low]} C:#{candle[:close]} (Aktuelle Stunde: #{candle[:isCurrentHour]}, Abgeschlossen: #{candle[:isComplete]})"
        end
      else
        Rails.logger.warn "🕯️ Keine 1h Kerzen gefunden für #{crypto.symbol}"
        current_candle_data[crypto.id] = []
      end
    end
    
    Rails.logger.info "🕯️ Gesamt aktuelle 1h Kerzen: #{current_candle_data.keys.length} Cryptos"
    current_candle_data
  end

  private

  def calculate_sum_24h_change(cryptocurrencies)
    sum = 0.0
    count = 0
    
    cryptocurrencies.each do |crypto|
      if crypto.price_change_percentage_24h && crypto.price_change_24h_complete?
        sum += crypto.price_change_percentage_24h
        count += 1
      end
    end
    
    count > 0 ? sum.round(2) : 0.0
  end

  def calculate_sum_1h_change(cryptocurrencies)
    sum = 0.0
    count = 0
    
    cryptocurrencies.each do |crypto|
      if crypto.price_change_percentage_1h && crypto.price_change_1h_complete?
        sum += crypto.price_change_percentage_1h
        count += 1
      end
    end
    
    count > 0 ? sum.round(2) : 0.0
  end

  def calculate_sum_30min_change(cryptocurrencies)
    sum = 0.0
    count = 0
    
    cryptocurrencies.each do |crypto|
      if crypto.price_change_percentage_30min && crypto.price_change_30min_complete?
        sum += crypto.price_change_percentage_30min
        count += 1
      end
    end
    
    count > 0 ? sum.round(2) : 0.0
  end
end 