# app/services/binance_websocket_service.rb
require 'websocket-client-simple'
require 'net/http'
require 'json'
require 'time' # Für Time.at

class BinanceWebsocketService
  BASE_URL = 'https://api.binance.com'
  WS_URL = 'wss://stream.binance.com:9443/ws/'

  def initialize
    @usdc_pairs = []
    @ws = nil
  end

  def start
    puts "🚀 Starte Binance USDC Pairs WebSocket Service..."
    
    # Lade alle USDC Pairs
    load_usdc_pairs
    
    if @usdc_pairs.empty?
      puts "❌ Keine USDC Pairs gefunden! Service wird beendet."
      return
    end

    puts "📊 Gefunden #{@usdc_pairs.length} USDC Pairs:"
    @usdc_pairs.each { |pair| puts "  - #{pair.upcase}" } # Symbol in Großbuchstaben ausgeben
    
    # Starte WebSocket Verbindung
    connect_websocket
    
    # Halte das Programm am Laufen
    keep_alive
  end

  private

  # Formatiert den Preis auf die entsprechende Anzahl von Dezimalstellen
  def format_price(price_str)
    price = price_str.to_f
    if price >= 1000
      sprintf('%.2f', price)
    elsif price >= 1
      sprintf('%.4f', price)
    else
      sprintf('%.8f', price)
    end
  end
  
  # Formatiert das Volumen mit K (Tausend) oder M (Million)
  def format_volume(volume_str)
    volume = volume_str.to_f
    if volume >= 1_000_000
      sprintf('%.2fM', volume / 1_000_000)
    elsif volume >= 1_000
      sprintf('%.2fK', volume / 1_000)
    else
      sprintf('%.2f', volume)
    end
  end

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
          .select { |s| s['status'] == 'TRADING' && s['quoteAsset'] == 'USDC' } # Prüfe quoteAsset
          .map { |s| s['symbol'].downcase } # Symbole für Stream in Kleinbuchstaben
          
        puts "✅ #{@usdc_pairs.length} aktive USDC Pairs geladen."
      else
        puts "❌ Fehler beim Laden der Pairs: HTTP-Code #{response.code} - #{response.body}"
      end
    rescue JSON::ParserError => e
      puts "❌ JSON Parse Fehler beim Laden der Pairs: #{e.message}"
    rescue => e
      puts "❌ Fehler beim API-Aufruf (exchangeInfo): #{e.message}"
    end
  end

  # Stellt die WebSocket-Verbindung her und registriert Event-Handler
  def connect_websocket
    # Erstelle Stream-Namen für alle USDC Pairs
    # Binance kline streams sind im Format <symbol>@kline_<interval>
    streams = @usdc_pairs.map { |pair| "#{pair}@kline_1m" }
    
    # Binance erlaubt max 1024 Streams pro Verbindung in einem kombinierten Stream
    if streams.length > 1024
      puts "⚠️  Zu viele Streams (#{streams.length}), beschränke auf 1024 für eine einzelne Verbindung."
      streams = streams.first(1024)
    end

    # WebSocket URL für kombinierte Streams
    ws_url = "#{WS_URL}#{streams.join('/')}"
    
    puts "🔌 Verbinde zu WebSocket unter: #{ws_url}"
    puts "📡 Abonnierte Streams: #{streams.length}"
    
    @ws = WebSocket::Client::Simple.connect(ws_url)
    
    # Event-Handler für eingehende Nachrichten
    @ws.on :message do |msg|
      begin
        json_data = JSON.parse(msg.data)
        
        # Prüfe, ob es sich um ein Kline-Event handelt und Kerzendaten vorhanden sind
        # Binance sendet kline-Events direkt mit 'e' und 'k' Schlüsseln auf der obersten Ebene
        if json_data['e'] == 'kline' && json_data['k']
          kline = json_data['k']
          symbol = json_data['s'] # Das Symbol ist auch auf der obersten Ebene der Nachricht

          # Nur geschlossene Kerzen ausgeben (x = true)
          if kline['x']
            # puts "🐛 Kerze ist geschlossen, verarbeite..."
            print_kline_data(symbol, kline)
          # else
            # puts "🐛 Kerze noch nicht geschlossen, überspringe..."
          end
        # else
          # puts "🐛 Keine Kerzendaten oder unbekanntes Event in Nachricht: #{json_data['e']}"
        end
      rescue JSON::ParserError => e
        puts "❌ JSON Parse Fehler bei Nachrichtenverarbeitung: #{e.message}"
        # puts "  Rohe Nachricht, die den Fehler verursachte: #{msg.data.inspect}"
      rescue => e
        puts "❌ Fehler bei Nachrichtenverarbeitung: #{e.class} - #{e.message}"
        puts "  Backtrace: #{e.backtrace.first(5).join(' -> ')}"
      end
    end

    # Event-Handler für offene Verbindung
    @ws.on :open do
      puts "✅ WebSocket Verbindung hergestellt!"
      puts "📈 Empfange 1m Kerzendaten für USDC Pairs..."
      puts "=" * 80
    end
    
    # Event-Handler für geschlossene Verbindung
    @ws.on :close do |e|
      puts "🔴 WebSocket Verbindung geschlossen: #{e.code} - #{e.reason}"
      # Optional: Automatische Wiederverbindung versuchen
      # sleep 5
      # connect_websocket
    end
    
    # Event-Handler für Fehler
    @ws.on :error do |e|
      puts "❌ WebSocket Fehler: #{e.message}"
    end
  end

  # Gibt die formatierten Kline-Daten auf der Konsole aus
  def print_kline_data(symbol, kline, status = "🟢")
    begin
      # Umwandlung des Millisekunden-Timestamps in ein Time-Objekt
      open_time = Time.at(kline['t'] / 1000).strftime('%Y-%m-%d %H:%M:%S')
      
      # Preise und Volumen formatieren
      open_price = format_price(kline['o'])
      high_price = format_price(kline['h'])
      low_price = format_price(kline['l'])
      close_price = format_price(kline['c'])
      volume = format_volume(kline['v'])
      
      # Preisänderung berechnen
      open_f = kline['o'].to_f
      close_f = kline['c'].to_f
      
      # Vermeide Division durch Null
      price_change = open_f != 0 ? ((close_f - open_f) / open_f * 100) : 0.0
      
      change_indicator = price_change >= 0 ? "🟢" : "🔴"
      final_status = status == "⏳" ? status : change_indicator
      
      puts "#{final_status} #{symbol.upcase.ljust(12)} | #{open_time} | " \
           "O: #{open_price.rjust(10)} | H: #{high_price.rjust(10)} | " \
           "L: #{low_price.rjust(10)} | C: #{close_price.rjust(10)} | " \
           "Vol: #{volume.rjust(12)} | Δ: #{sprintf('%+.2f%%', price_change).rjust(8)}"
      
      puts "=" * 80
      
    rescue => e
      puts "❌ Fehler in print_kline_data: #{e.message}"
      puts "  Backtrace: #{e.backtrace.first(3).join(' -> ')}"
      puts "  Kline-Daten (Fehlerhaft): #{kline.inspect}"
    end
  end

  # Hält das Programm am Laufen und fängt Beendigungssignale ab
  def keep_alive
    puts "\n💡 Service läuft... Drücke Ctrl+C zum Beenden\n\n"
    
    trap('INT') do
      puts "\n🛑 Service wird beendet..."
      @ws&.close # Schließt die WebSocket-Verbindung, falls offen
      puts "👋 Auf Wiedersehen!"
      exit 0
    end
    
    # Endlose Schleife, um den Hauptthread aktiv zu halten
    loop do
      sleep 1
    end
  end
end

# Direktes Ausführen des Services, wenn die Datei direkt aufgerufen wird
if __FILE__ == $0
  BinanceWebsocketService.new.start
end




