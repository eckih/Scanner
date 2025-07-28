namespace :crypto do
  desc "Teste und debugge RSI-Berechnung für eine spezifische Kryptowährung"
  task test_rsi_calculation: :environment do
    puts "🧪 Teste RSI-Berechnung..."
    
    # Finde NEWT/USDT oder die erste verfügbare Kryptowährung
    crypto = Cryptocurrency.find_by(symbol: "BTC/USDC") || Cryptocurrency.first
    
    unless crypto
      puts "❌ Keine Kryptowährung in der Datenbank gefunden"
      exit 1
    end
    
    puts "📊 Teste RSI-Berechnung für: #{crypto.symbol}"
    
    # Teste verschiedene Timeframes
    timeframes = ['1m', '5m', '15m', '1h', '4h']
    period = 14
    
    timeframes.each do |timeframe|
      puts "\n" + "="*50
      puts "🔍 Timeframe: #{timeframe}, Periode: #{period}"
      puts "="*50
      
      # Zeige verfügbare Daten
      total_data = CryptoHistoryData.where(
        cryptocurrency: crypto,
        interval: timeframe
      ).count
      
      puts "📊 Verfügbare Datensätze: #{total_data}"
      
      if total_data < period + 1
        puts "⚠️ Nicht genug Daten für RSI-Berechnung (benötigt: #{period + 1})"
        next
      end
      
      # Hole die Daten wie im Service
      historical_data = CryptoHistoryData.where(
        cryptocurrency: crypto,
        interval: timeframe
      ).order(timestamp: :desc).limit(period + 1)
      
      puts "📈 Letzte #{period + 1} Kerzen (neueste zuerst):"
      historical_data.each_with_index do |data, index|
        puts "  #{index + 1}. #{data.timestamp.strftime('%Y-%m-%d %H:%M')} - Close: $#{data.close_price}"
      end
      
      # Sortiere chronologisch für RSI-Berechnung
      close_prices = historical_data.reverse.pluck(:close_price)
      puts "\n💰 Close-Preise (chronologisch):"
      close_prices.each_with_index do |price, index|
        puts "  #{index + 1}. $#{price}"
      end
      
      # Berechne Änderungen
      changes = []
      (1...close_prices.length).each do |i|
        change = close_prices[i] - close_prices[i-1]
        changes << change
        puts "  Änderung #{i}: $#{close_prices[i-1]} → $#{close_prices[i]} = #{change > 0 ? '+' : ''}#{change.round(6)}"
      end
      
      # Verwende nur die letzten 'period' Änderungen
      recent_changes = changes.last(period)
      puts "\n📊 Letzte #{period} Änderungen für RSI:"
      recent_changes.each_with_index do |change, index|
        puts "  #{index + 1}. #{change > 0 ? '+' : ''}#{change.round(6)}"
      end
      
      # Berechne Gewinne und Verluste
      gains = recent_changes.map { |change| change > 0 ? change : 0 }
      losses = recent_changes.map { |change| change < 0 ? change.abs : 0 }
      
      puts "\n📈 Gewinne: #{gains.map { |g| g.round(6) }}"
      puts "📉 Verluste: #{losses.map { |l| l.round(6) }}"
      
      # Berechne Durchschnitte
      avg_gain = gains.sum.to_f / period
      avg_loss = losses.sum.to_f / period
      
      puts "\n🧮 Durchschnittlicher Gewinn: #{avg_gain.round(6)}"
      puts "🧮 Durchschnittlicher Verlust: #{avg_loss.round(6)}"
      
      # Berechne RSI
      if avg_loss == 0
        rsi = 50.0
        puts "⚠️ Keine Verluste vorhanden, RSI = 50"
      else
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
        puts "🧮 RS (Relative Strength): #{rs.round(6)}"
        puts "📊 RSI: #{rsi.round(2)}"
      end
      
      # Vergleiche mit Service-Berechnung
      puts "\n🔬 Vergleich mit Service-Berechnung:"
              service_rsi = IndicatorCalculationService.calculate_and_save_rsi(crypto, timeframe, period)
      puts "Service RSI: #{service_rsi}"
      puts "Manual RSI:  #{rsi.round(2)}"
      puts service_rsi == rsi.round(2) ? "✅ Übereinstimmung!" : "❌ Abweichung!"
    end
    
    puts "\n🎉 RSI-Test abgeschlossen!"
  end
end 