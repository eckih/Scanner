module CryptoConfig
  extend ActiveSupport::Concern
  
  def self.settings
    {
      rsi_period: 14,
      roc_period: 14,
      roc_derivative_period: 14
    }
  end
  
  def self.update_settings(params)
    # Hier würde die echte Einstellungsaktualisierung stattfinden
    Rails.logger.info "Settings updated: #{params}"
    true
  rescue => e
    Rails.logger.error "Error updating settings: #{e.message}"
    false
  end
end 