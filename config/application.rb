# require 'logger'
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Scanner
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments/, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Lade das CryptoConfig Modul global
    config.autoload_paths << Rails.root.join('app', 'models', 'concerns')
    
    # Setze die Zeitzone auf Berlin (MEZ/MESZ)
    config.time_zone = 'Europe/Berlin'
  end
end

# Globale Konfiguration für Kryptowährungs-Scanner
module CryptoConfig
  # ROC (Rate of Change) Periode - standardmäßig 14 Perioden
  ROC_PERIOD = 14
  
  # RSI (Relative Strength Index) Periode - standardmäßig 14 Perioden
  RSI_PERIOD = 14
  
  # Standard-Zeitrahmen für Indikatoren
  DEFAULT_INTERVAL = '1h'
  
  # Anzahl der Top-Kryptowährungen für die Anzeige
  TOP_CRYPTO_COUNT = 50
  
  # Anzahl der Kryptowährungen für automatische ROC-Berechnung
  AUTO_ROC_COUNT = 5
end 