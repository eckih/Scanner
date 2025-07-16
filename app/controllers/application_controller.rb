class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  # Hilfsmethoden für Views verfügbar machen
  helper_method :format_german_time, :format_german_time_short
  
  private
  
  def handle_api_error(error)
    Rails.logger.error "API Error: #{error.message}"
    flash[:alert] = "Fehler beim Abrufen der Daten. Bitte versuchen Sie es später erneut."
  end
  
  # Hilfsmethode für deutsche Zeitformatierung mit MEZ/MESZ
  def format_german_time(time)
    return nil unless time
    
    # Prüfe ob Sommerzeit (MESZ) oder Winterzeit (MEZ)
    timezone_abbr = time.in_time_zone('Europe/Berlin').dst? ? 'MESZ' : 'MEZ'
    time.in_time_zone('Europe/Berlin').strftime("%d.%m.%Y %H:%M:%S #{timezone_abbr}")
  end
  
  # Hilfsmethode für deutsche Zeitformatierung ohne Sekunden
  def format_german_time_short(time)
    return nil unless time
    
    # Prüfe ob Sommerzeit (MESZ) oder Winterzeit (MEZ)
    timezone_abbr = time.in_time_zone('Europe/Berlin').dst? ? 'MESZ' : 'MEZ'
    time.in_time_zone('Europe/Berlin').strftime("%d.%m.%Y %H:%M #{timezone_abbr}")
  end
end 