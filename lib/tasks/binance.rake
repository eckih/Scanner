namespace :binance do
  desc "Fetch all cryptocurrency prices and RSI from Binance and update database"
  task fetch_all_cryptos: :environment do
    puts "=" * 50
    puts "BINANCE CRYPTOCURRENCY DATA FETCHER (ALL USDC PAIRS)"
    puts "=" * 50
    
    start_time = Time.current
    
    begin
      BinanceService.fetch_and_update_all_cryptos
      
      end_time = Time.current
      duration = (end_time - start_time).round(2)
      
      puts "=" * 50
      puts "SUMMARY:"
      puts "Total cryptocurrencies in database: #{Cryptocurrency.count}"
      puts "Duration: #{duration} seconds"
      puts "Last updated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 50
      
    rescue => e
      puts "ERROR: #{e.message}"
      puts e.backtrace.first(5)
    end
  end

  desc "Fetch top 50 cryptocurrencies only (faster) - USDC pairs"
  task fetch_top_50: :environment do
    puts "=" * 50
    puts "BINANCE TOP 50 CRYPTOCURRENCY DATA FETCHER (USDC PAIRS)"
    puts "=" * 50
    
    start_time = Time.current
    
    begin
      # Verwende die neue get_top_usdc_pairs Methode
      top_symbols = BinanceService.get_top_usdc_pairs
      
      BinanceService.fetch_specific_cryptos(top_symbols)
      
      end_time = Time.current
      duration = (end_time - start_time).round(2)
      
      puts "=" * 50
      puts "SUMMARY:"
      puts "Total cryptocurrencies in database: #{Cryptocurrency.count}"
      puts "Duration: #{duration} seconds"
      puts "Last updated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 50
      
    rescue => e
      puts "ERROR: #{e.message}"
      puts e.backtrace.first(5)
    end
  end

  desc "Auto-refresh data every 5 minutes (background task)"
  task auto_refresh: :environment do
    puts "=" * 50
    puts "STARTING AUTO-REFRESH SERVICE (Every 5 minutes)"
    puts "=" * 50
    
    loop do
      begin
        puts "[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] Fetching latest cryptocurrency data..."
        
        start_time = Time.current
        top_symbols = BinanceService.get_top_usdc_pairs
        BinanceService.fetch_specific_cryptos(top_symbols)
        
        end_time = Time.current
        duration = (end_time - start_time).round(2)
        
        puts "[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] Update completed in #{duration}s. Next update in 5 minutes..."
        
        # Warte 5 Minuten (300 Sekunden)
        sleep(300)
        
      rescue => e
        puts "[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] ERROR: #{e.message}"
        puts "Retrying in 1 minute..."
        sleep(60)
      end
    end
  end

  desc "Clear all cryptocurrency data"
  task clear_data: :environment do
    puts "Clearing all cryptocurrency data..."
    count = Cryptocurrency.count
    Cryptocurrency.destroy_all
    puts "Deleted #{count} cryptocurrency records."
  end
end 