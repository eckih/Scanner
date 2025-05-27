class CryptocurrenciesController < ApplicationController
  before_action :set_cryptocurrency, only: [:show]
  
  def index
    @cryptocurrencies = Cryptocurrency.top_50
    @last_update = Cryptocurrency.maximum(:last_updated)
    
    # Wenn keine Daten vorhanden sind, versuche sie zu laden
    if @cryptocurrencies.empty?
      begin
        Cryptocurrency.refresh_from_api
        @cryptocurrencies = Cryptocurrency.top_50
        flash.now[:success] = "Kryptowährungsdaten erfolgreich geladen!"
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
      Cryptocurrency.refresh_from_api
      flash[:success] = "Daten erfolgreich aktualisiert!"
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