namespace :rsi do
  desc "Initialisiere RSI-Cache mit historischen Daten"
  task initialize_cache: :environment do
    puts "🔄 Initialisiere RSI-Cache mit historischen Daten..."
    
    # Lade aktuelle Frontend-Einstellungen
    timeframe = Rails.cache.read('frontend_selected_timeframe') || '1h'
    period = Rails.cache.read('frontend_selected_rsi_period') || 14
    
    puts "📊 Verwende Timeframe: #{timeframe}, Periode: #{period}"
    
    Cryptocurrency.find_each do |crypto|
      puts "🔄 Initialisiere Cache für #{crypto.symbol}..."
      
      # Hole historische Daten für den Cache
      historical_data = CryptoHistoryData.where(
        cryptocurrency: crypto,
        interval: timeframe
      ).order(timestamp: :desc).limit(period + 1)
      
      if historical_data.count >= period + 1
        # Manuell Cache mit historischen Daten füllen
        cache_key = "#{crypto.id}_#{timeframe}_#{period}"
        price_cache = []
        
        historical_data.reverse.each do |data|
          price_cache << { price: data.close_price, timestamp: data.timestamp }
        end
        
        # Setze Cache direkt
        RealtimeRsiService.class_variable_get(:@@rsi_cache)[cache_key] = price_cache
        
        # Berechne RSI aus Cache
        prices = price_cache.map { |entry| entry[:price] }
        rsi_value = RealtimeRsiService.calculate_rsi_from_prices(prices, period)
        
        puts "✅ #{crypto.symbol}: RSI = #{rsi_value} (#{price_cache.length} Preise im Cache)"
      else
        puts "⚠️ #{crypto.symbol}: Nicht genügend historische Daten (#{historical_data.count} von #{period + 1})"
      end
    end
    
    puts "✅ RSI-Cache Initialisierung abgeschlossen!"
  end
  
  desc "Zeige Cache-Status"
  task cache_status: :environment do
    puts "📊 RSI-Cache Status:"
    
    # Debug-Informationen
    RealtimeRsiService.debug_cache_status
    
    Cryptocurrency.find_each do |crypto|
      timeframe = Rails.cache.read('frontend_selected_timeframe') || '1h'
      period = Rails.cache.read('frontend_selected_rsi_period') || 14
      
      cached_prices = RealtimeRsiService.get_cached_prices(crypto, timeframe, period)
      current_rsi = crypto.current_rsi(timeframe, period)
      
      puts "  #{crypto.symbol}: #{cached_prices.length} Preise im Cache, RSI = #{current_rsi}"
    end
  end
  
  desc "Lösche RSI-Cache"
  task clear_cache: :environment do
    puts "🗑️ Lösche RSI-Cache..."
    RealtimeRsiService.clear_cache
    puts "✅ RSI-Cache gelöscht!"
  end
end 