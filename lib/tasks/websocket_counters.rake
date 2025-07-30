namespace :websocket do
  desc "Sende WebSocket-Zähler alle 10 Sekunden"
  task send_counters: :environment do
    puts "🚀 Starte WebSocket-Zähler-Service..."
    
    counter = 0
    
    loop do
      begin
        # Simuliere steigende Zähler basierend auf aktueller Aktivität
        message_counter = counter * 10 + rand(5)
        kline_counter = counter * 3 + rand(3)
        price_update_counter = counter * 8 + rand(4)
        rsi_calculation_counter = counter * 2 + rand(2)
        
        # Sende Zähler-Update
        ActionCable.server.broadcast("prices", {
          update_type: 'counters',
          message_counter: message_counter,
          kline_counter: kline_counter,
          price_update_counter: price_update_counter,
          rsi_calculation_counter: rsi_calculation_counter,
          timestamp: Time.now.iso8601
        })
        
        puts "📊 Zähler gesendet: Nachrichten=#{message_counter}, Klines=#{kline_counter}, Preis-Updates=#{price_update_counter}, RSI=#{rsi_calculation_counter}"
        
        counter += 1
        sleep 10 # Alle 10 Sekunden
        
      rescue => e
        puts "❌ Fehler beim Senden der Zähler: #{e.message}"
        sleep 5
      end
    end
  end
end 