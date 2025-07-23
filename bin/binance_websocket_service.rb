#!/usr/bin/env ruby
require 'websocket-client-simple'
require 'json'
require 'time'
require 'net/http'
require 'set'
require_relative '../config/environment'

# Hilfsfunktion: Lese und filtere Paare aus bot.json
class PairSelector
  def self.load_pairs
    config = JSON.parse(File.read(File.join(__dir__, '../config/bot.json')))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    blacklist = config.dig('exchange', 'pair_blacklist') || []

    # Hole alle aktiven Trading-Paare von Binance
    uri = URI('https://api.binance.com/api/v3/exchangeInfo')
    response = Net::HTTP.get_response(uri)
    raise "Fehler beim Laden der Binance-Paare: #{response.code}" unless response.code == '200'
    data = JSON.parse(response.body)
    symbols = data['symbols']

    # Whitelist-Filter (Regex oder explizite Paare)
    pairs = symbols.select { |s| s['status'] == 'TRADING' }
    if whitelist.any? { |w| w.include?('.*') }
      regexes = whitelist.map { |w| Regexp.new(w.gsub('/', '').gsub('.*', '.*')) }
      pairs = pairs.select { |s| regexes.any? { |r| s['symbol'] =~ r } }
    else
      allowed = whitelist.map { |p| p.gsub('/', '').upcase }
      binance_symbols = pairs.map { |s| s['symbol'].upcase }
      found = binance_symbols & allowed
      puts "Gefundene Paare: #{found.inspect}"
      pairs = pairs.select { |s| allowed.include?(s['symbol'].upcase) }
    end
    # Blacklist-Filter
    if blacklist.any?
      blocked = blacklist.map { |p| p.gsub('/', '') }
      pairs = pairs.reject { |s| blocked.include?(s['symbol']) }
    end
    pairs.map { |s| s['symbol'].downcase }
  end
end

class BinanceWebsocketService
  WS_URL = 'wss://stream.binance.com:9443/ws/'

  def initialize(pairs)
    @pairs = pairs
    @ws = nil
  end

  def start
    puts "Starte Binance Websocket-Service für #{@pairs.length} Paare"
    
    @pairs.each do |pair|
      start_single_stream(pair)
      sleep(0.1) # Kleine Pause zwischen Verbindungen
    end
    
    keep_alive
  end

  def start_single_stream(pair)
    loop do
      begin
        puts "Verbinde zu: #{WS_URL}#{pair}@kline_1m"
        ws = WebSocket::Client::Simple.connect("#{WS_URL}#{pair}@kline_1m")
        
        service = self
        ws.on :open do
          puts "✅ Verbindung für #{pair} hergestellt"
        end
        
        ws.on :message do |msg|
          puts "RAW-Nachricht empfangen: #{msg.data[0..50]}..."
          service.handle_message(msg.data)
        end
        
        ws.on :close do |e|
          puts "🔴 Verbindung für #{pair} geschlossen: #{e.code}"
          raise "Connection closed"
        end
        
        ws.on :error do |e|
          puts "❌ Fehler für #{pair}: #{e.message}"
          raise "Connection error"
        end
        
        # Halte die Verbindung offen
        loop { sleep(1) }
        
      rescue => e
        puts "❌ Verbindungsfehler für #{pair}: #{e.message}"
        puts " Versuche Reconnect in 5 Sekunden..."
        sleep(5)
      end
    end
  end

  def handle_message(data)
    return unless data.start_with?('{') || data.start_with?('[')
    begin
      json_data = JSON.parse(data)
      # Binance sendet einzelne Hashes
      if json_data['e'] == 'kline' && json_data['k']
        kline = json_data['k']
        symbol = json_data['s']
        if kline['x'] # Nur abgeschlossene Kerzen speichern
          save_kline(symbol, kline)
        end
      end
    rescue => e
      puts "❌ Fehler beim Verarbeiten der Nachricht: #{e.class} - #{e.message}"
    end
  end

  def save_kline(symbol, kline)
    # Typkonvertierung und Mapping
    cryptocurrency = Cryptocurrency.find_by(symbol: symbol)
    unless cryptocurrency
      cryptocurrency = Cryptocurrency.create!(
        symbol: symbol,
        name: symbol, # Fallback, besser wäre Mapping
        current_price: kline['c'].to_f > 0 ? kline['c'].to_f : 1,
        market_cap: 1,
        market_cap_rank: 9999
      )
    end
    attrs = {
      cryptocurrency: cryptocurrency,
      timestamp: Time.at(kline['t'] / 1000),
      open: kline['o'].to_f,
      high: kline['h'].to_f,
      low: kline['l'].to_f,
      close: kline['c'].to_f,
      volume: kline['v'].to_f,
      interval: '1m',
    }
    CryptoHistoryData.record_data(attrs[:cryptocurrency], attrs, '1m')
    puts "[#{attrs[:timestamp]}] #{symbol} O:#{attrs[:open]} H:#{attrs[:high]} L:#{attrs[:low]} C:#{attrs[:close]} V:#{attrs[:volume]}"
  rescue => e
    puts "❌ Fehler beim Speichern der Kline: #{e.class} - #{e.message}"
  end

  def keep_alive
    puts "Service läuft... (Ctrl+C zum Beenden)"
    trap('INT') do
      puts "\nBeende Service..."
      @ws&.close
      exit 0
    end
    loop { sleep 1 }
  end
end

if __FILE__ == $0
  begin
    pairs = PairSelector.load_pairs
    if pairs.empty?
      puts "Keine gültigen Paare gefunden!"
      exit 1
    end
    BinanceWebsocketService.new(pairs).start
  rescue => e
    puts "❌ Fehler beim Starten des Services: #{e.class} - #{e.message}"
    puts e.backtrace.first(10).join("\n")
    exit 1
  end
end 