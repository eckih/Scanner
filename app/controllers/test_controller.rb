class TestController < ApplicationController
  def index
    render plain: "Test Controller - OK"
  end

  def rsi
    # Test RSI-Broadcast
    ActionCable.server.broadcast("prices", {
      update_type: 'rsi',
      cryptocurrency_id: 153, # BTC/USDC
      symbol: 'BTC/USDC',
      rsi: 65.42,
      timestamp: Time.now.iso8601
    })
    render json: { status: 'RSI broadcast sent' }
  end

  def price
    # Test Preis-Broadcast
    ActionCable.server.broadcast("prices", {
      cryptocurrency_id: 153, # BTC/USDC
      symbol: 'BTC/USDC',
      price: 43250.50,
      realtime: true,
      timestamp: Time.now.iso8601
    })
    render json: { status: 'Price broadcast sent' }
  end

  def counter
    # Test Counter-Broadcast
    ActionCable.server.broadcast("prices", {
      update_type: 'counters',
      message_counter: 100,
      kline_counter: 50,
      price_update_counter: 75,
      data_rate: 120.5,
      timestamp: Time.now.iso8601
    })
    render json: { status: 'Counter broadcast sent' }
  end

  def start_simulator
    # Starte Simulator in Hintergrund
    Thread.new do
      loop do
        begin
          # Sende Updates für alle Pairs
          pairs = [
            { id: 153, symbol: 'BTC/USDC', base_price: 43250.50 },
            { id: 154, symbol: 'ETH/USDC', base_price: 2650.30 },
            { id: 155, symbol: 'BNB/USDC', base_price: 580.45 },
            { id: 156, symbol: 'ADA/USDC', base_price: 0.485 },
            { id: 157, symbol: 'SOL/USDC', base_price: 98.75 },
            { id: 158, symbol: 'NEWT/USDC', base_price: 0.0025 }
          ]
          
          pairs.each do |pair|
            # Preis-Update
            price_change = rand(-2.0..2.0) / 100.0
            new_price = pair[:base_price] * (1 + price_change)
            
            ActionCable.server.broadcast("prices", {
              cryptocurrency_id: pair[:id],
              symbol: pair[:symbol],
              price: new_price.round(6),
              realtime: true,
              timestamp: Time.now.iso8601
            })
          end
          
          # Counter-Update
          ActionCable.server.broadcast("prices", {
            update_type: 'counters',
            message_counter: rand(150..300),
            kline_counter: rand(80..150),
            price_update_counter: rand(120..200),
            data_rate: rand(100..180),
            timestamp: Time.now.iso8601
          })
          
          Rails.logger.info "📡 Simulator Updates gesendet"
          sleep 5 # Alle 5 Sekunden
        rescue => e
          Rails.logger.error "❌ Simulator Fehler: #{e.message}"
          sleep 10
        end
      end
    end
    
    render json: { status: 'Simulator started' }
  end

  def start_websocket_service
    # Teste die reparierte PairSelector Methode
    begin
      require_relative '../../bin/binance_websocket_service'
      
      Rails.logger.info "🔧 Teste PairSelector..."
      pairs = PairSelector.load_pairs
      Rails.logger.info "✅ Pairs geladen: #{pairs.inspect}"
      
      # Starte WebSocket Service in Hintergrund
      Thread.new do
        Rails.logger.info "🚀 Starte reparierten WebSocket Service..."
        start_binance_websocket_service
      end
      
      render json: { 
        status: 'WebSocket Service gestartet',
        pairs: pairs
      }
    rescue => e
      Rails.logger.error "❌ Fehler beim Starten des WebSocket Service: #{e.message}"
      render json: { 
        error: e.message,
        backtrace: e.backtrace.first(3)
      }
    end
  end
end 