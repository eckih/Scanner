namespace :crypto do
  desc "Update cryptocurrency data from Binance"
  task update: :environment do
    puts "Starting manual cryptocurrency update..."
    CryptoDataLoader.load_real_cryptocurrency_data
    puts "Manual update completed!"
  end

  desc "Start the update scheduler"
  task start_scheduler: :environment do
    puts "Starting cryptocurrency update scheduler..."
    puts "Update interval: #{Rails.application.config.crypto_update_interval} seconds"
    
    loop do
      begin
        puts "[#{Time.current}] Starting scheduled update..."
        CryptocurrencyUpdateJob.perform_later
        puts "[#{Time.current}] Update job queued. Waiting #{Rails.application.config.crypto_update_interval} seconds..."
        sleep Rails.application.config.crypto_update_interval
      rescue => e
        puts "Scheduler error: #{e.message}"
        sleep 60
      end
    end
  end

  desc "Show current cryptocurrency data"
  task status: :environment do
    puts "Cryptocurrency Database Status:"
    puts "=" * 50
    puts "Total cryptocurrencies: #{Cryptocurrency.count}"
    puts "Last updated: #{Cryptocurrency.maximum(:updated_at)}"
    puts "Update interval: #{Rails.application.config.crypto_update_interval} seconds"
    
    if Cryptocurrency.count > 0
      puts "\nTop 5 cryptocurrencies:"
      Cryptocurrency.order(:market_cap_rank).limit(5).each do |crypto|
        puts "  #{crypto.market_cap_rank}. #{crypto.name} (#{crypto.symbol}) - $#{crypto.current_price} - RSI: #{crypto.rsi}"
      end
    end
  end
end 