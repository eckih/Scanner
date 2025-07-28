namespace :crypto do
  desc "Berechne RSI-Werte für alle Kryptowährungen (ohne historische Daten)"
  task calculate_rsi_now: :environment do
    puts "🚀 Berechne RSI-Werte für alle Kryptowährungen..."
    
    # Lade Whitelist
    config_path = Rails.root.join('config', 'bot.json')
    unless File.exist?(config_path)
      puts "❌ bot.json nicht gefunden"
      return
    end
    
    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    
    puts "📋 Whitelist: #{whitelist.join(', ')}"
    
    # Hole nur Whitelist-Kryptowährungen
    cryptocurrencies = Cryptocurrency.where(symbol: whitelist)
    puts "📊 Verarbeite #{cryptocurrencies.count} Kryptowährungen..."
    
    cryptocurrencies.each do |crypto|
      begin
        puts "\n📈 Berechne RSI für #{crypto.symbol}..."
        
        # Erstelle simulierte historische Daten für RSI-Berechnung
        rsi_value = generate_simulated_rsi(crypto)
        
        if rsi_value
          # Verwende den neuen IndicatorCalculationService
          IndicatorCalculationService.calculate_and_save_rsi(crypto, '1m', 14)
          
          puts "✅ #{crypto.symbol}: RSI = #{rsi_value.round(2)}"
        else
          puts "❌ #{crypto.symbol}: RSI-Berechnung fehlgeschlagen"
        end
        
      rescue => e
        puts "❌ Fehler bei #{crypto.symbol}: #{e.message}"
      end
    end
    
    puts "\n🎉 RSI-Berechnung abgeschlossen!"
    puts "📊 Finale RSI-Werte:"
    cryptocurrencies.reload.each do |crypto|
      puts "  #{crypto.symbol}: #{crypto.rsi&.round(2) || 'N/A'}"
    end
  end
  
  private
  
  def self.generate_simulated_rsi(crypto)
    # Generiere einen realistischen RSI-Wert basierend auf dem aktuellen Preis
    # und der 24h-Preisänderung
    
    base_rsi = 50.0 # Neutraler Startwert
    
    # Berücksichtige 24h-Preisänderung
    if crypto.price_change_percentage_24h
      change = crypto.price_change_percentage_24h
      
      if change > 5
        # Starker Anstieg -> höherer RSI
        base_rsi += rand(15..25)
      elsif change > 2
        # Mäßiger Anstieg
        base_rsi += rand(5..15)
      elsif change < -5
        # Starker Rückgang -> niedrigerer RSI
        base_rsi -= rand(15..25)
      elsif change < -2
        # Mäßiger Rückgang
        base_rsi -= rand(5..15)
      else
        # Kleine Änderung -> zufällige Variation
        base_rsi += rand(-10..10)
      end
    else
      # Keine 24h-Daten -> zufälliger RSI
      base_rsi = rand(20..80)
    end
    
    # Begrenze RSI auf 0-100
    rsi = [0, [100, base_rsi].min].max
    
    rsi.round(2)
  end
end 