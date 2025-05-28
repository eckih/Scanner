class CryptocurrenciesController < ApplicationController
  before_action :set_cryptocurrency, only: [:show, :chart]
  
  def index
    @cryptocurrencies = Cryptocurrency.top_50
    @last_update = Cryptocurrency.maximum(:updated_at)
    
    # Wenn keine Daten vorhanden sind, versuche sie zu laden
    if @cryptocurrencies.empty?
      begin
        # Verwende Top 10 USDC-Paare für schnelles Laden
        top_10_usdc = BinanceService.get_top_usdc_pairs.first(10)
        BinanceService.fetch_specific_cryptos(top_10_usdc)
        @cryptocurrencies = Cryptocurrency.top_50
        flash.now[:success] = "Kryptowährungsdaten erfolgreich von Binance geladen! (USDC-Paare)"
      rescue StandardError => e
        handle_api_error(e)
        @cryptocurrencies = []
      end
    end
  end
  
  def show
    @cryptocurrency = Cryptocurrency.find(params[:id])
  end
  
  def chart
    @cryptocurrency = Cryptocurrency.find(params[:id])
    
    begin
      # Hole historische Daten von Binance für verschiedene Zeiträume
      # Das Symbol ist bereits im Format BTCUSDC, also verwende es direkt
      symbol = @cryptocurrency.symbol
      
      # 24h Daten (5-Minuten-Intervall)
      @chart_data_24h = BinanceService.get_historical_data(symbol, '5m', '1 day ago UTC')
      
      # 7 Tage Daten (1-Stunden-Intervall)
      @chart_data_7d = BinanceService.get_historical_data(symbol, '1h', '7 days ago UTC')
      
      # 30 Tage Daten (4-Stunden-Intervall)
      @chart_data_30d = BinanceService.get_historical_data(symbol, '4h', '30 days ago UTC')
      
    rescue StandardError => e
      Rails.logger.error "Chart data error: #{e.message}"
      flash.now[:alert] = "Fehler beim Laden der Chart-Daten: #{e.message}"
      @chart_data_24h = []
      @chart_data_7d = []
      @chart_data_30d = []
    end
  end
  
  def refresh_data
    begin
      # Verwende den neuen BinanceService für Top 50 USDC-Kryptowährungen
      top_symbols = BinanceService.get_top_usdc_pairs
      BinanceService.fetch_specific_cryptos(top_symbols)
      flash[:success] = "Daten erfolgreich von Binance API aktualisiert! (#{top_symbols.length} USDC-Paare, 1h RSI)"
    rescue StandardError => e
      handle_api_error(e)
    end
    
    redirect_to cryptocurrencies_path
  end
  
  private
  
  def set_cryptocurrency
    @cryptocurrency = Cryptocurrency.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Kryptowährung nicht gefunden."
    redirect_to cryptocurrencies_path
  end
  
  def handle_api_error(error)
    Rails.logger.error "API Error: #{error.message}"
    flash.now[:alert] = "Fehler beim Laden der Daten: #{error.message}"
  end
end 