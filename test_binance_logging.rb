#!/usr/bin/env ruby

# Einfacher Test für Binance Logging
require_relative 'config/environment'

puts "Testing Binance logging..."

begin
  # Test des Loggers
  BinanceService.binance_logger.info("STANDALONE TEST: Binance logger is working")
  puts "✓ Logger test successful"
  
  # Test der Log-Methoden
  BinanceService.log_binance_request('/test/endpoint', {param: 'value'})
  BinanceService.log_binance_success('/test/endpoint', 'Test successful')
  BinanceService.log_binance_error('/test/endpoint', 'Test error')
  
  puts "✓ Log methods test successful"
  puts "Check log/binance.log for test entries"
  
rescue => e
  puts "✗ Error testing logging: #{e.message}"
  puts e.backtrace.first(5)
end 