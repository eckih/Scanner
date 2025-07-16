class CryptocurrenciesController < ApplicationController
  before_action :set_cryptocurrency, only: [:show, :chart]
  
  # Konfiguration direkt im Controller
  ROC_PERIOD = 14
  RSI_PERIOD = 14
  DEFAULT_INTERVAL = '1h'
  AUTO_ROC_COUNT = 5
  
  def index
    # Prüfe und füge roc-Spalte hinzu, falls sie nicht existiert
    begin
      ActiveRecord::Base.connection.execute("SELECT roc FROM cryptocurrencies LIMIT 1")
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("no such column: roc")
        ActiveRecord::Base.connection.execute("ALTER TABLE cryptocurrencies ADD COLUMN roc DECIMAL(10,2)")
      end
    end

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
    else
      # Automatisch ROC-Werte für die ersten Coins berechnen, wenn sie fehlen
      records_without_roc = @cryptocurrencies.select { |c| c.roc.nil? }.first(AUTO_ROC_COUNT)
      if records_without_roc.any?
        records_without_roc.each do |crypto|
          begin
            roc = BinanceService.calculate_roc_for_symbol(crypto.symbol, DEFAULT_INTERVAL)
            if roc
              Cryptocurrency.where(id: crypto.id).update_all(roc: roc)
            end
            sleep(0.1) # Rate limiting
          rescue => e
            # Stille Fehlerbehandlung
          end
        end
        # Lade die Daten neu, um die aktualisierten ROC-Werte zu erhalten
        @cryptocurrencies = Cryptocurrency.top_50
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
      flash[:success] = "Daten erfolgreich von Binance API aktualisiert! (#{top_symbols.length} USDC-Paare, 1h RSI, 14h ROC)"
    rescue StandardError => e
      handle_api_error(e)
    end
    
    redirect_to cryptocurrencies_path
  end

  def update_roc
    begin
      BinanceService.update_roc_for_all_cryptocurrencies
      flash[:success] = "ROC-Werte erfolgreich für alle Kryptowährungen aktualisiert!"
    rescue StandardError => e
      handle_api_error(e)
    end
    
    redirect_to cryptocurrencies_path
  end

  def settings
    # Einstellungsseite anzeigen
  end

  def update_settings
    begin
      # Aktualisiere die Controller-Konstanten
      roc_period = params[:roc_period] || ROC_PERIOD
      rsi_period = params[:rsi_period] || RSI_PERIOD
      auto_roc_count = params[:auto_roc_count] || AUTO_ROC_COUNT
      default_interval = params[:default_interval] || DEFAULT_INTERVAL
      
      # Aktualisiere die Controller-Konstanten (einfache Lösung)
      CryptocurrenciesController.const_set(:ROC_PERIOD, roc_period.to_i)
      CryptocurrenciesController.const_set(:RSI_PERIOD, rsi_period.to_i)
      CryptocurrenciesController.const_set(:AUTO_ROC_COUNT, auto_roc_count.to_i)
      CryptocurrenciesController.const_set(:DEFAULT_INTERVAL, default_interval)
      
      # Aktualisiere auch die Service-Konstanten
      BinanceService.const_set(:ROC_PERIOD, roc_period.to_i)
      BinanceService.const_set(:RSI_PERIOD, rsi_period.to_i)
      BinanceService.const_set(:DEFAULT_INTERVAL, default_interval)
      
      flash[:success] = "Einstellungen erfolgreich gespeichert! Die Änderungen sind sofort wirksam."
    rescue StandardError => e
      flash[:alert] = "Fehler beim Speichern der Einstellungen: #{e.message}"
    end
    
    redirect_to settings_cryptocurrencies_path
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