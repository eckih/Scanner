namespace :crypto do
  desc "Teste die neue Indikator-Struktur"
  task test_new_indicators: :environment do
    puts "🧪 Teste neue Indikator-Struktur..."
    
    # Teste mit der ersten Kryptowährung
    crypto = Cryptocurrency.first
    if crypto
      puts "📊 Teste mit: #{crypto.symbol}"
      
      # Teste RSI-Berechnung
      puts "🔍 Teste RSI-Berechnung..."
      rsi_result = IndicatorCalculationService.calculate_and_save_rsi(crypto, '15m', 14)
      puts "  RSI Ergebnis: #{rsi_result}"
      
      # Teste ROC-Berechnung
      puts "🔍 Teste ROC-Berechnung..."
      roc_result = IndicatorCalculationService.calculate_and_save_roc(crypto, '15m', 14)
      puts "  ROC Ergebnis: #{roc_result}"
      
      # Teste ROC Derivative-Berechnung
      puts "🔍 Teste ROC Derivative-Berechnung..."
      roc_der_result = IndicatorCalculationService.calculate_and_save_roc_derivative(crypto, '15m', 14)
      puts "  ROC Derivative Ergebnis: #{roc_der_result}"
      
      # Zeige gespeicherte Indikatoren
      puts "📋 Gespeicherte Indikatoren:"
      crypto.indicators.latest.limit(5).each do |indicator|
        puts "  #{indicator.indicator_type.upcase} (#{indicator.timeframe}, #{indicator.period}): #{indicator.value.round(4)} - #{indicator.calculated_at}"
      end
      
      # Teste Convenience-Methoden
      puts "🔧 Teste Convenience-Methoden:"
      puts "  current_rsi: #{crypto.current_rsi}"
      puts "  current_roc: #{crypto.current_roc}"
      puts "  current_roc_derivative: #{crypto.current_roc_derivative}"
      
      # Teste Historie-Methoden
      puts "📈 Teste Historie-Methoden:"
      rsi_history = crypto.rsi_history('15m', 14, 5)
      puts "  RSI Historie (5 Einträge): #{rsi_history.length} Einträge"
      
      roc_history = crypto.roc_history('15m', 14, 5)
      puts "  ROC Historie (5 Einträge): #{roc_history.length} Einträge"
      
    else
      puts "❌ Keine Kryptowährung gefunden"
    end
    
    # Zeige Statistiken
    puts "📊 Statistiken:"
    puts "  Gesamt Indikatoren: #{Indicator.count}"
    puts "  RSI Indikatoren: #{Indicator.rsi.count}"
    puts "  ROC Indikatoren: #{Indicator.roc.count}"
    puts "  ROC Derivative Indikatoren: #{Indicator.roc_derivative.count}"
    
    puts "✅ Test abgeschlossen!"
  end
end 