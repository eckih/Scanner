class CryptocurrenciesController < ApplicationController
  ROC_PERIOD = 24 # Standard ROC-Periode in Stunden
  
  # CSRF-Schutz für AJAX-Endpoints deaktivieren
  skip_before_action :verify_authenticity_token, only: [:refresh_data, :update_roc, :add_roc_derivative]

  def index
    @cryptocurrencies = Cryptocurrency.order(:market_cap_rank)
    @last_update = Cryptocurrency.maximum(:updated_at)
    @update_interval = Rails.application.config.crypto_update_interval
    calculate_trends_for_cryptocurrencies
  end

  def show
    @cryptocurrency = Cryptocurrency.find(params[:id])
    @chart_data = create_chart_data(@cryptocurrency.rsi_histories, @cryptocurrency.roc_histories, @cryptocurrency.roc_derivative_histories)
  end

  def refresh_data
    # Starte Background-Job für Datenaktualisierung
    CryptocurrencyUpdateJob.perform_later
    
    respond_to do |format|
      format.html { redirect_to cryptocurrencies_path, notice: 'Datenaktualisierung wurde im Hintergrund gestartet.' }
      format.json { render json: { status: 'started', message: 'Datenaktualisierung wurde im Hintergrund gestartet.' } }
    end
  end

  def update_roc
    # Starte Background-Job für ROC-Aktualisierung
    CryptocurrencyUpdateJob.perform_later
    
    respond_to do |format|
      format.html { redirect_to cryptocurrencies_path, notice: 'ROC-Berechnung wurde im Hintergrund gestartet.' }
      format.json { render json: { status: 'started', message: 'ROC-Berechnung wurde im Hintergrund gestartet.' } }
    end
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
    @chart_data = create_chart_data(
      RsiHistory.all,
      RocHistory.all,
      RocDerivativeHistory.all
    )
  end

  def chart
    @cryptocurrency = Cryptocurrency.find(params[:id])
    @chart_data = create_chart_data(@cryptocurrency.rsi_histories, @cryptocurrency.roc_histories, @cryptocurrency.roc_derivative_histories)
  end

  def chart_data
    @cryptocurrency = Cryptocurrency.find(params[:id])
    @chart_data = create_chart_data(@cryptocurrency.rsi_histories, @cryptocurrency.roc_histories, @cryptocurrency.roc_derivative_histories)
    
    render json: @chart_data
  end

  private

  def settings_params
    params.require(:settings).permit(:rsi_period, :roc_period, :roc_derivative_period)
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
end 