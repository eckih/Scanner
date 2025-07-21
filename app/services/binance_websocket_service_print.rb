# app/services/binance_websocket_service_print.rb
require 'websocket-client-simple'
require 'net/http'
require 'json'
require 'time' # Für Time.at

# Stellt eine WebSocket-Verbindung zu Binance her, um 1m Kerzendaten
# für alle USDC-Paare zu empfangen und auf der Konsole auszugeben.
class BinanceWebsocketService
  BASE_URL = 'https://api.binance.com'
  WS_URL = 'wss://stream.binance.com:9443/ws/'

  def initialize
    @usdc_pairs = []
    @ws = nil
  end

  # Startet den Service-Lebenszyklus
  def start
    puts "🚀 Starte Binance USDC Pairs WebSocket Service..."
    
    load_usdc_pairs
    
    if @usdc_pairs.empty?
      puts "❌ Keine USDC Pairs gefunden! Service wird beendet."
      return
    end

    puts "📊 Gefunden #{@usdc_pairs.length} USDC Pairs:"
    @usdc_pairs.each { |pair| puts "  - #{pair.upcase}" }
    
    connect_websocket
    
    keep_alive
  end

  # Die folgenden Methoden sind private Helfermethoden
  private

  # Lädt alle aktiven USDC Trading Pairs von der Binance API
  def load_usdc_pairs
    puts "🔍 Lade alle Trading Pairs von Binance..."
    
    begin
      uri = URI("#{BASE_URL}/api/v3/exchangeInfo")
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        symbols = data['symbols']
        
        @usdc_pairs = symbols
          .select { |s| s['status'] == 'TRADING' && s['quoteAsset'] == 'USDC' }
          .map { |s| s['symbol'].downcase }
          
        puts "✅ #{@usdc_pairs.length} aktive USDC Pairs geladen."
      else
        puts "❌ Fehler beim Laden der Pairs: HTTP-Code #{response.code}"
      end
    rescue JSON::ParserError => e
      puts "❌ JSON Parse Fehler beim Laden der Pairs: #{e.message}"
    rescue => e
      puts "❌ Fehler beim API-Aufruf (exchangeInfo): #{e.message}"
    end
  end

  # Stellt die WebSocket-Verbindung her und registriert Event-Handler
  def connect_websocket
    streams = @usdc_pairs.map { |pair| "#{pair}@kline_1m" }
    
    if streams.length > 1024
      puts "⚠️  Zu viele Streams (#{streams.length}), beschränke auf 1024."
      streams = streams.first(1024)
    end

    ws_url = "#{WS_URL}#{streams.join('/')}"
    
    puts "🔌 Verbinde zu WebSocket unter: #{ws_url}" # Die URL ist wichtig für Debugging
    puts "📡 Abonnierte Streams: #{streams.length}"
    
    # Speichere die Instanz in einer lokalen Variable, damit sie im Block zugänglich ist
    service_instance = self

    @ws = WebSocket::Client::Simple.connect(ws_url)
    
    @ws.on :message do |msg|
      if msg.data.start_with?('{') || msg.data.start_with?('[')
        begin
          json_data = JSON.parse(msg.data)
          
          data_to_process = case json_data
                            when Array then json_data
                            when Hash then [json_data]
                            else []
                            end

          data_to_process.each do |item|
            if item['e'] == 'kline' && item['k']
              kline = item['k']
              symbol = item['s']
              
              if kline['x']
                puts "✅ Kerze für #{symbol.upcase} abgeschlossen."
                
                # Nutze die gespeicherte Variable, um die Methode aufzurufen
                # Die Methode print_kline_data ist jetzt public, daher ist dies erlaubt.
                service_instance.print_kline_data(symbol, kline)
              end
            end
          end
        rescue JSON::ParserError => e
          puts "❌ JSON Parse Fehler: #{e.message}"
        rescue => e
          puts "❌ Fehler bei Nachrichtenverarbeitung: #{e.class} - #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(5).join(' -> ')}"
          # exit 1 
        end
      else
        puts "ℹ️  Nicht-JSON Nachricht empfangen: #{msg.data}"
      end
    end

    @ws.on :open do
      puts "✅ WebSocket Verbindung hergestellt!"
      puts "📈 Empfange 1m Kerzendaten für USDC Pairs..."
      puts "=" * 80
    end
    
    @ws.on :close do |e|
      puts "🔴 WebSocket Verbindung geschlossen: #{e.code} - #{e.reason}"
    end
    
    @ws.on :error do |e|
      puts "❌ WebSocket Fehler: #{e.message}"
    end
  end
  
  # Formatiert und gibt die Kline-Daten auf der Konsole aus
  # Diese Methode ist absichtlich nicht 'private', damit sie über service_instance aufgerufen werden kann.

  public
  
  def print_kline_data(symbol, kline)
    begin
      open_time = Time.at(kline['t'] / 1000).strftime('%Y-%m-%d %H:%M:%S')
      
      # Stellen Sie sicher, dass die Werte in Float umgewandelt werden, bevor sprintf verwendet wird
      open_price = sprintf('%.8f', kline['o'].to_f)
      high_price = sprintf('%.8f', kline['h'].to_f)
      low_price = sprintf('%.8f', kline['l'].to_f)
      close_price = sprintf('%.8f', kline['c'].to_f)
      
      volume = sprintf('%.2f', kline['v'].to_f) # Volumen ebenfalls formatieren
      
      open_f = kline['o'].to_f
      close_f = kline['c'].to_f
      price_change = open_f != 0 ? ((close_f - open_f) / open_f * 100) : 0.0
      
      change_indicator = price_change >= 0 ? "🟢" : "🔴"
      
      puts "#{change_indicator} #{symbol.upcase.ljust(12)} | #{open_time} | " \
           "O: #{open_price} | H: #{high_price} | L: #{low_price} | C: #{close_price} | " \
           "Vol: #{volume} | Δ: #{sprintf('%+.2f%%', price_change)}"
      
      puts "=" * 80
    rescue => e
      puts "❌ Fehler in print_kline_data: #{e.message}"
      puts "  Fehlerhafte Kline-Daten: #{kline.inspect}" # Zusätzliche Debug-Info
    end
  end

  # Hält den Service am Laufen
  def keep_alive
    puts "\n💡 Service läuft... Drücke Ctrl+C zum Beenden\n\n"
    
    trap('INT') do
      puts "\n🛑 Service wird beendet..."
      @ws&.close
      puts "👋 Auf Wiedersehen!"
      exit 0
    end
    
    loop do
      sleep 1
    end
  end
end

# Direktes Ausführen des Services, wenn die Datei direkt aufgerufen wird
if __FILE__ == $0
  BinanceWebsocketService.new.start
end