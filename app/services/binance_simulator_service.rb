class BinanceSimulatorService
  def self.start
    puts "🚀 Starte Binance Simulator Service..."
    
    # Simuliere echte Binance-Daten für alle Pairs
    pairs = [
      { id: 153, symbol: 'BTC/USDC', base_price: 43250.50 },
      { id: 154, symbol: 'ETH/USDC', base_price: 2650.30 },
      { id: 155, symbol: 'BNB/USDC', base_price: 580.45 },
      { id: 156, symbol: 'ADA/USDC', base_price: 0.485 },
      { id: 157, symbol: 'SOL/USDC', base_price: 98.75 },
      { id: 158, symbol: 'NEWT/USDC', base_price: 0.0025 }
    ]
    
    Thread.new do
      loop do
        begin
          pairs.each do |pair|
            # Simuliere Preis-Update
            price_change = rand(-2.0..2.0) / 100.0 # ±2% Änderung
            new_price = pair[:base_price] * (1 + price_change)
            
            ActionCable.server.broadcast("prices", {
              cryptocurrency_id: pair[:id],
              symbol: pair[:symbol],
              price: new_price.round(6),
              realtime: true,
              timestamp: Time.now.iso8601
            })
            
            # Simuliere RSI-Update (alle 30 Sekunden)
            if Time.now.to_i % 30 == 0
              rsi_value = 30 + rand(40) # RSI zwischen 30-70
              ActionCable.server.broadcast("prices", {
                update_type: 'rsi',
                cryptocurrency_id: pair[:id],
                symbol: pair[:symbol],
                rsi: rsi_value,
                timestamp: Time.now.iso8601
              })
            end
          end
          
          # Simuliere Counter-Update
          ActionCable.server.broadcast("prices", {
            update_type: 'counters',
            message_counter: rand(150..300),
            kline_counter: rand(80..150),
            price_update_counter: rand(120..200),
            data_rate: rand(100..180),
            timestamp: Time.now.iso8601
          })
          
          Rails.logger.info "📡 Binance Simulator Updates gesendet"
          sleep 3 # Alle 3 Sekunden
        rescue => e
          Rails.logger.error "❌ Fehler im Binance Simulator: #{e.message}"
          sleep 10
        end
      end
    end
    
    Rails.logger.info "✅ Binance Simulator Service gestartet"
  end
end 