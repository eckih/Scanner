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

    # Effizient: Hash mit den letzten Preisen für alle Cryptos (immer 1m für Echtzeit-Updates)
    subquery = CryptoHistoryData.select('MAX(timestamp) as max_time, cryptocurrency_id')
                                .where(interval: '1m')
                                .group(:cryptocurrency_id)
    
    @latest_prices = CryptoHistoryData.joins("INNER JOIN (#{subquery.to_sql}) sub ON crypto_history_data.cryptocurrency_id = sub.cryptocurrency_id AND crypto_history_data.timestamp = sub.max_time")
                                      .where(interval: '1m')
                                      .pluck(:cryptocurrency_id, :close_price)
                                      .to_h
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
end 