class ColumnSumService
  def self.calculate_and_save_sums
    Rails.logger.info "📊 Berechne und speichere Spalten-Summen..."
    
    begin
      # Lade alle Kryptowährungen aus der Whitelist
      config_path = File.join(Rails.root, 'config/bot.json')
      config = JSON.parse(File.read(config_path))
      whitelist = config.dig('exchange', 'pair_whitelist') || []
      
      cryptocurrencies = Cryptocurrency.where(symbol: whitelist)
      
      sum_24h = 0.0
      sum_1h = 0.0
      sum_30min = 0.0
      count_24h = 0
      count_1h = 0
      count_30min = 0
      
      cryptocurrencies.each do |crypto|
        # 24h Summe - verwende dynamische Berechnung
        change_24h = crypto.calculate_24h_change
        if change_24h && crypto.has_24h_data?
          sum_24h += change_24h
          count_24h += 1
        end
        
        # 1h Summe - verwende dynamische Berechnung
        change_1h = crypto.calculate_1h_change
        if change_1h && crypto.has_1h_data?
          sum_1h += change_1h
          count_1h += 1
        end
        
        # 30min Summe - verwende dynamische Berechnung
        change_30min = crypto.calculate_30min_change
        if change_30min && crypto.has_30min_data?
          sum_30min += change_30min
          count_30min += 1
        end
      end
      
      # Speichere in der Datenbank
      ColumnSum.create!(
        sum_24h: sum_24h.round(2),
        sum_1h: sum_1h.round(2),
        sum_30min: sum_30min.round(2),
        count_24h: count_24h,
        count_1h: count_1h,
        count_30min: count_30min,
        calculated_at: Time.current
      )
      
      Rails.logger.info "✅ Spalten-Summen gespeichert: 24h=#{sum_24h.round(2)} (#{count_24h}), 1h=#{sum_1h.round(2)} (#{count_1h}), 30min=#{sum_30min.round(2)} (#{count_30min})"
      
      # Broadcaste Update für Frontend
      broadcast_sum_update(sum_24h.round(2), sum_1h.round(2), sum_30min.round(2), count_24h, count_1h, count_30min)
      
    rescue => e
      Rails.logger.error "[X] Fehler beim Berechnen der Spalten-Summen: #{e.class} - #{e.message}"
    end
  end
  
  private
  
  def self.broadcast_sum_update(sum_24h, sum_1h, sum_30min, count_24h, count_1h, count_30min)
    begin
      ActionCable.server.broadcast("prices", {
        update_type: 'column_sums',
        sum_24h: sum_24h,
        sum_1h: sum_1h,
        sum_30min: sum_30min,
        count_24h: count_24h,
        count_1h: count_1h,
        count_30min: count_30min,
        timestamp: Time.now.iso8601
      })
      Rails.logger.debug "📡 Spalten-Summen gebroadcastet"
    rescue => e
      Rails.logger.error "[X] Fehler beim Broadcast der Spalten-Summen: #{e.message}"
    end
  end
end
