class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  private
  
  def handle_api_error(error)
    Rails.logger.error "API Error: #{error.message}"
    flash[:alert] = "Fehler beim Abrufen der Daten. Bitte versuchen Sie es später erneut."
  end
end 