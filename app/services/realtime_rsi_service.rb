class RealtimeRsiService
  # Thread-sichere Cache für RSI-Berechnungen
  @@rsi_cache = Concurrent::Map.new
  
  def self.calculate_realtime_rsi(cryptocurrency, new_price, timeframe = '1m', period = 14)
    cache_key = "#{cryptocurrency.id}_#{timeframe}_#{period}"
    
    # Hole oder initialisiere den Preis-Cache für diese Kryptowährung
    price_cache = @@rsi_cache.fetch(cache_key) { [] }
    
    # Füge den neuen Preis hinzu
    current_time = Time.now
    price_cache << { price: new_price, timestamp: current_time }
    
    # Behalte nur die letzten (period + 1) Preise
    if price_cache.length > period + 1
      price_cache = price_cache.last(period + 1)
    end
    
    # Aktualisiere den Cache
    @@rsi_cache[cache_key] = price_cache
    
    # Berechne RSI nur wenn genügend Daten vorhanden sind
    if price_cache.length >= period + 1
      prices = price_cache.map { |entry| entry[:price] }
      rsi_value = calculate_rsi_from_prices(prices, period)
      
      if rsi_value
        # Speichere in Datenbank und broadcaste
        save_and_broadcast_rsi(cryptocurrency, rsi_value, timeframe, period)
        return rsi_value
      end
    end
    
    nil
  end
  
  def self.get_cached_prices(cryptocurrency, timeframe = '1m', period = 14)
    cache_key = "#{cryptocurrency.id}_#{timeframe}_#{period}"
    @@rsi_cache[cache_key] || []
  end
  
  def self.debug_cache_status
    puts "🔍 RSI-Cache Debug:"
    puts "  Cache-Keys: #{@@rsi_cache.keys}"
    puts "  Cache-Größe: #{@@rsi_cache.size}"
    
    @@rsi_cache.each do |key, prices|
      puts "  #{key}: #{prices.length} Preise"
    end
  end
  
  def self.clear_cache(cryptocurrency = nil)
    if cryptocurrency
      # Lösche Cache für spezifische Kryptowährung
      @@rsi_cache.keys.each do |key|
        if key.start_with?("#{cryptocurrency.id}_")
          @@rsi_cache.delete(key)
        end
      end
    else
      # Lösche gesamten Cache
      @@rsi_cache.clear
    end
  end
  
  
  def self.calculate_rsi_from_prices(prices, period)
    return nil if prices.length < period + 1
    
    # Berechne Gewinne und Verluste
    gains = []
    losses = []
    
    (1...prices.length).each do |i|
      change = prices[i] - prices[i - 1]
      if change > 0
        gains << change
        losses << 0
      else
        gains << 0
        losses << change.abs
      end
    end
    
    # Berechne durchschnittliche Gewinne und Verluste
    avg_gain = gains.last(period).sum.to_f / period
    avg_loss = losses.last(period).sum.to_f / period
    
    return nil if avg_loss == 0
    
    # Berechne RSI
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    
    rsi.round(2)
  end
  
  def self.save_and_broadcast_rsi(cryptocurrency, rsi_value, timeframe, period)
    # Speichere in indicators Tabelle
    existing_indicator = Indicator.where(
      cryptocurrency: cryptocurrency,
      indicator_type: 'rsi',
      timeframe: timeframe,
      period: period
    ).where('calculated_at >= ?', 1.minute.ago).first
    
    if existing_indicator
      existing_indicator.update!(value: rsi_value, calculated_at: Time.now)
    else
      Indicator.create!(
        cryptocurrency: cryptocurrency,
        indicator_type: 'rsi',
        value: rsi_value,
        timeframe: timeframe,
        period: period,
        calculated_at: Time.now
      )
    end
    
    # Broadcaste Update
    ActionCable.server.broadcast(
      'prices_channel',
      {
        update_type: 'indicator',
        indicator_type: 'rsi',
        symbol: cryptocurrency.symbol,
        value: rsi_value,
        timeframe: timeframe,
        period: period,
        cryptocurrency_id: cryptocurrency.id
      }
    )
  end
end 