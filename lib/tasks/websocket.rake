namespace :websocket do
  desc "Start Binance WebSocket Service (sauber ohne doppelte Einträge)"
  task start: :environment do
    puts "🚀 Starte Binance WebSocket Service (direkt)..."
    
    # Stoppe alle laufenden Services (nur innerhalb des Containers)
    system("pkill -f binance_websocket_service 2>/dev/null || true")
    sleep 1
    
    # Starte den Service direkt in einem Thread
    Thread.new do
      begin
        require_relative '../../bin/binance_websocket_service'
        Rails.logger.info "🚀 WebSocket Service wird in Thread gestartet..."
        start_binance_websocket_service
      rescue => e
        Rails.logger.error "❌ Fehler beim Starten des WebSocket Service: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
    
    sleep 2 # Kurz warten, damit der Thread startet
    puts "✅ WebSocket Service gestartet (in Thread)"
    puts "📊 Prüfe Logs mit: docker compose logs web --tail=10"
  end
  
  desc "Stop Binance WebSocket Service"
  task stop: :environment do
    puts "🛑 Stoppe Binance WebSocket Service..."
    system("docker compose exec web pkill -f binance_websocket_service")
    puts "✅ WebSocket Service gestoppt"
  end
  
  desc "Restart Binance WebSocket Service"
  task restart: :environment do
    Rake::Task['websocket:stop'].invoke
    sleep 3
    Rake::Task['websocket:start'].invoke
  end

  desc "Test ActionCable Broadcast"
  task test_broadcast: :environment do
    puts "📡 Sende Test-Broadcast..."
    ActionCable.server.broadcast("prices", {
      cryptocurrency_id: 153,
      symbol: 'BTC/USDC',
      price: 43250.50,
      realtime: true,
      timestamp: Time.now.iso8601
    })
    puts "✅ Test-Broadcast gesendet"
  end

  desc "Start WebSocket Service direkt"
  task start_direct: :environment do
    puts "🚀 Starte WebSocket Service direkt..."
    load 'bin/binance_websocket_service.rb'
    start_binance_websocket_service
  end

  desc "Start Test Update Service"
  task start_test_updates: :environment do
    puts "🚀 Starte Test Update Service..."
    
    # Sende regelmäßig Test-Updates
    Thread.new do
      loop do
        begin
          # Test Preis-Update für BTC/USDC
          ActionCable.server.broadcast("prices", {
            cryptocurrency_id: 153,
            symbol: 'BTC/USDC',
            price: 43250.50 + rand(-100..100),
            realtime: true,
            timestamp: Time.now.iso8601
          })
          
          # Test RSI-Update
          ActionCable.server.broadcast("prices", {
            update_type: 'rsi',
            cryptocurrency_id: 153,
            symbol: 'BTC/USDC',
            rsi: 50 + rand(-20..20),
            timestamp: Time.now.iso8601
          })
          
          # Test Counter-Update
          ActionCable.server.broadcast("prices", {
            update_type: 'counters',
            message_counter: rand(100..200),
            kline_counter: rand(50..100),
            price_update_counter: rand(75..150),
            data_rate: rand(80..150),
            timestamp: Time.now.iso8601
          })
          
          puts "📡 Test-Updates gesendet"
          sleep 5 # Alle 5 Sekunden
        rescue => e
          puts "❌ Fehler beim Senden von Test-Updates: #{e.message}"
          sleep 10
        end
      end
    end
    
    puts "✅ Test Update Service gestartet - Updates alle 5 Sekunden"
    puts "🛑 Drücke Ctrl+C zum Stoppen"
    
    # Warte auf Interrupt
    loop do
      sleep 1
    end
  end

  desc "Start Binance Simulator (ersetzt echten WebSocket-Service)"
  task start_simulator: :environment do
    puts "🚀 Starte Binance Simulator..."
    
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
          
          puts "📡 Binance Simulator Updates gesendet"
          sleep 3 # Alle 3 Sekunden
        rescue => e
          puts "❌ Fehler im Binance Simulator: #{e.message}"
          sleep 10
        end
      end
    end
    
    puts "✅ Binance Simulator gestartet - Echte Daten simuliert"
    puts "🛑 Drücke Ctrl+C zum Stoppen"
    
    # Warte auf Interrupt
    loop do
      sleep 1
    end
  end
end 