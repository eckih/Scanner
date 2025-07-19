namespace :historical_data do
  desc "Generiere historische Daten für alle Kryptowährungen"
  task generate: :environment do
    puts "Generiere historische Daten für alle Kryptowährungen..."
    
    period = ENV['PERIOD']&.to_i || 100
    puts "Verwende Periode: #{period}"
    
    Cryptocurrency.find_each do |crypto|
      begin
        puts "Generiere historische Daten für #{crypto.name} (#{crypto.symbol})..."
        BinanceService.store_historical_data_for_crypto(crypto, period)
        puts "✓ Historische Daten für #{crypto.name} generiert"
      rescue => e
        puts "✗ Fehler bei #{crypto.name}: #{e.message}"
      end
    end
    
    puts "Historische Daten-Generierung abgeschlossen!"
  end
  
  desc "Bereinige alte historische Daten"
  task cleanup: :environment do
    period = ENV['PERIOD']&.to_i || 100
    puts "Bereinige historische Daten, behalte #{period} neueste Einträge..."
    
    CryptoHistoryData.cleanup_old_data(period)
    puts "Bereinigung abgeschlossen!"
  end
  
  desc "Zeige Statistiken der historischen Daten"
  task stats: :environment do
    puts "Statistiken der historischen Daten:"
    puts "=" * 50
    
    total_records = CryptoHistoryData.count
    puts "Gesamte Datensätze: #{total_records}"
    
    intervals = %w[1h 4h 1d]
    intervals.each do |interval|
      count = CryptoHistoryData.where(interval: interval).count
      puts "#{interval} Intervalle: #{count} Datensätze"
    end
    
    cryptos_with_data = CryptoHistoryData.distinct.count(:cryptocurrency_id)
    puts "Kryptowährungen mit historischen Daten: #{cryptos_with_data}"
    
    if total_records > 0
      oldest = CryptoHistoryData.order(:timestamp).first
      newest = CryptoHistoryData.order(:timestamp).last
      puts "Zeitraum: #{oldest.timestamp} bis #{newest.timestamp}"
    end
  end
end 