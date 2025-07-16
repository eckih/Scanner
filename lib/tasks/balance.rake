namespace :balance do
  # Hilfsmethode für deutsche Zeitformatierung
  def format_german_time(time)
    return nil unless time
    
    # Prüfe ob Sommerzeit (MESZ) oder Winterzeit (MEZ)
    timezone_abbr = time.in_time_zone('Europe/Berlin').dst? ? 'MESZ' : 'MEZ'
    time.in_time_zone('Europe/Berlin').strftime("%Y-%m-%d %H:%M:%S #{timezone_abbr}")
  end

  desc "Aktualisiere Balance-Daten von Binance"
  task update: :environment do
    puts "Starting balance update task..."
    
    begin
      BalanceService.fetch_and_update_balances
      puts "Balance update completed successfully!"
    rescue => e
      puts "Error during balance update: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
  
  desc "Bereinige alte Balance-Daten (älter als 30 Tage)"
  task cleanup: :environment do
    puts "Starting balance cleanup task..."
    
    cutoff_date = 30.days.ago
    deleted_count = Balance.where("created_at < ?", cutoff_date).delete_all
    
    puts "Deleted #{deleted_count} old balance records older than #{cutoff_date}"
  end
  
  desc "Zeige aktuelle Balance-Statistiken"
  task stats: :environment do
    puts "=== Balance Statistics ==="
    puts "Total records: #{Balance.count}"
    puts "Assets with balance: #{Balance.all_assets_with_balance.count}"
    puts "Last update: #{format_german_time(Balance.maximum(:created_at))}"
    
    total_balance = Balance.latest_total_balance
    if total_balance
      puts "Current total USD: #{total_balance.formatted_usd}"
      puts "Current total BTC: #{total_balance.formatted_btc}"
    else
      puts "No balance data available"
    end
  end
end 