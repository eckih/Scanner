class CryptocurrenciesController < ApplicationController
  before_action :set_cryptocurrency, only: [:show]
  
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