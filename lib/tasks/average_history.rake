namespace :average_history do
  desc "Erstelle die AverageHistory-Tabelle"
  task create_table: :environment do
    begin
      # Prüfe, ob die Tabelle bereits existiert
      ActiveRecord::Base.connection.execute("SELECT 1 FROM average_histories LIMIT 1")
      puts "✓ AverageHistory-Tabelle existiert bereits"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("no such table: average_histories")
        puts "Erstelle AverageHistory-Tabelle..."
        
        # Erstelle die Tabelle manuell
        ActiveRecord::Base.connection.create_table :average_histories do |t|
          t.string :metric_type, null: false
          t.decimal :average_value, precision: 10, scale: 4, null: false
          t.datetime :recorded_at, null: false
          t.integer :period_count, default: 0
          
          t.timestamps
        end
        
        # Erstelle Indizes
        ActiveRecord::Base.connection.add_index :average_histories, [:metric_type, :recorded_at]
        ActiveRecord::Base.connection.add_index :average_histories, :recorded_at
        
        puts "✓ AverageHistory-Tabelle erfolgreich erstellt"
      else
        puts "✗ Fehler beim Erstellen der Tabelle: #{e.message}"
      end
    end
  end
  
  desc "Fülle die AverageHistory-Tabelle mit initialen Daten"
  task seed_data: :environment do
    puts "Erstelle initiale Durchschnittswerte..."
    
    # Hole aktuelle Kryptowährungsdaten
    cryptocurrencies = Cryptocurrency.all
    
    if cryptocurrencies.any?
      # Berechne aktuelle Durchschnittswerte
      valid_rsi_values = cryptocurrencies.map(&:current_rsi).compact.select { |rsi| rsi > 0 }
      valid_roc_values = cryptocurrencies.map(&:current_roc).compact.select { |roc| roc != 0 }
      valid_roc_derivative_values = cryptocurrencies.map(&:current_roc_derivative).compact.select { |roc_der| roc_der != 0 }
      
      # Erstelle historische Einträge für die letzten 10 Perioden
      10.times do |i|
        time = i.hours.ago
        
        if valid_rsi_values.any?
          avg_rsi = (valid_rsi_values.sum / valid_rsi_values.length.to_f).round(2)
          # Füge leichte Variation hinzu
          varied_rsi = avg_rsi + rand(-2.0..2.0)
          AverageHistory.create!(
            metric_type: 'rsi',
            average_value: varied_rsi,
            recorded_at: time,
            period_count: valid_rsi_values.length
          )
        end
        
        if valid_roc_values.any?
          avg_roc = (valid_roc_values.sum / valid_roc_values.length.to_f).round(2)
          varied_roc = avg_roc + rand(-1.0..1.0)
          AverageHistory.create!(
            metric_type: 'roc',
            average_value: varied_roc,
            recorded_at: time,
            period_count: valid_roc_values.length
          )
        end
        
        if valid_roc_derivative_values.any?
          avg_roc_derivative = (valid_roc_derivative_values.sum / valid_roc_derivative_values.length.to_f).round(2)
          varied_roc_derivative = avg_roc_derivative + rand(-0.5..0.5)
          AverageHistory.create!(
            metric_type: 'roc_derivative',
            average_value: varied_roc_derivative,
            recorded_at: time,
            period_count: valid_roc_derivative_values.length
          )
        end
      end
      
      puts "✓ Initiale Durchschnittswerte erstellt"
    else
      puts "✗ Keine Kryptowährungsdaten verfügbar"
    end
  end
end 