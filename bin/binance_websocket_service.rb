#!/usr/bin/env ruby
require 'websocket-client-simple'
require 'json'
require 'time'
require 'net/http'
require 'set'
require 'logger' # Für bessere Protokollierung
require 'concurrent' # Für Concurrent-Programmierung, z.B. Timer
require_relative '../config/environment' # Rails-Umgebung laden (stellt Cryptocurrency und CryptoHistoryData bereit)

# --- Konfiguration ---
BINANCE_WS_BASE_URL = 'wss://stream.binance.com:9443/ws'
BINANCE_API_EXCHANGE_INFO_URL = 'https://api.binance.com/api/v3/exchangeInfo'
PING_INTERVAL_SECONDS = 30 # Sekunden: Wie oft wir einen Ping senden (Binance-Empfehlung ca. alle 3 Minuten, aber aggressiver ist sicherer)
PONG_TIMEOUT_SECONDS = 120 # WICHTIG: Erhöht auf 120 Sekunden (2 Minuten)
RECONNECT_INITIAL_DELAY_SECONDS = 5 # Sekunden: Startverzögerung für Reconnect (exponentieller Backoff)
RECONNECT_MAX_DELAY_SECONDS = 60 # Sekunden: Maximale Verzögerung für exponentiellen Backoff

# --- Logger initialisieren ---
# Der Logger gibt detaillierte Informationen über den Ablauf des Skripts aus.
LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::DEBUG # WICHTIG: Auf DEBUG setzen, um alle Debug-Ausgaben zu sehen
LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] [#{severity}] #{msg}\n"
end

# --- Hilfsfunktion: Lese und filtere Paare aus bot.json ---
# Diese Klasse ist für das Laden und Filtern der Handelspaare zuständig.
class PairSelector
  # Lädt die Paare aus der bot.json und filtert diese.
  def self.load_pairs
    config_path = File.join(__dir__, '../config/bot.json')
    unless File.exist?(config_path)
      LOGGER.error "Konfigurationsdatei nicht gefunden: #{config_path}"
      raise "Konfigurationsdatei bot.json nicht gefunden. Bitte stellen Sie sicher, dass sie im 'config'-Verzeichnis liegt."
    end

    config = JSON.parse(File.read(config_path))
    whitelist = config.dig('exchange', 'pair_whitelist') || []
    blacklist = config.dig('exchange', 'pair_blacklist') || []

    LOGGER.info "Lade aktive Trading-Paare von Binance API..."
    uri = URI(BINANCE_API_EXCHANGE_INFO_URL)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      LOGGER.error "Fehler beim Laden der Binance-Paare: #{response.code} - #{response.message}"
      raise "Fehler beim Laden der Binance-Paare: #{response.code} #{response.message}"
    end

    data = JSON.parse(response.body)
    symbols = data['symbols']

    active_pairs = symbols.select { |s| s['status'] == 'TRADING' }

    # Whitelist-Filterung: Erlaubt explizite Paare oder Regex-Muster
    if whitelist.any?
      if whitelist.any? { |w| w.include?('.*') || w.include?('*') } # Prüfen auf Regex-Muster
        regexes = whitelist.map { |w| Regexp.new(w.gsub('/', '').gsub('*', '.*'), Regexp::IGNORECASE) }
        active_pairs = active_pairs.select { |s| regexes.any? { |r| s['symbol'] =~ r } }
        LOGGER.info "Whitelist (Regex) angewendet: #{whitelist.inspect}"
      else # Explizite Paare
        allowed_symbols = whitelist.map { |p| p.gsub('/', '').upcase }.to_set
        active_pairs = active_pairs.select { |s| allowed_symbols.include?(s['symbol'].upcase) }
        LOGGER.info "Whitelist (explizit) angewendet: #{whitelist.inspect}"
      end
    else
      LOGGER.warn "Keine Whitelist konfiguriert. Alle TRADING-Paare werden berücksichtigt."
    end

    # Blacklist-Filterung: Entfernt unerwünschte Paare
    if blacklist.any?
      blocked_symbols = blacklist.map { |p| p.gsub('/', '').upcase }.to_set
      active_pairs = active_pairs.reject { |s| blocked_symbols.include?(s['symbol'].upcase) }
      LOGGER.info "Blacklist angewendet: #{blacklist.inspect}"
    end

    selected_pairs = active_pairs.map { |s| s['symbol'].downcase }
    LOGGER.info "Ausgewählte Paare für den Stream: #{selected_pairs.join(', ')} (#{selected_pairs.length} Paare)"
    selected_pairs
  rescue StandardError => e
    LOGGER.fatal "Fehler in PairSelector.load_pairs: #{e.message}\n#{e.backtrace.join("\n")}"
    raise e # Fehler weitergeben, um das Skript zu beenden
  end
end

# --- Haupt-Service-Klasse ---
# Diese Klasse verwaltet die WebSocket-Verbindung zu Binance und die Datenverarbeitung.
class BinanceWebsocketService
  attr_reader :ws, :last_pong_at, :reconnect_attempt

  def initialize(pairs)
    @pairs = pairs # Die Liste der zu abonnierenden Paare
    @ws = nil # Dies wird die WebSocket::Client::Simple::Client Instanz sein
    @last_pong_at = Time.now # Letzter Zeitpunkt, zu dem Daten oder ein Pong empfangen wurde
    @ping_timer = nil # Timer zum Senden von Pings
    @pong_timeout_timer = nil # Timer zur Überwachung des Pong-Timeouts
    @reconnect_attempt = 0 # Zähler für Reconnect-Versuche
    @mutex = Mutex.new # Für Thread-Sicherheit beim Zugriff auf @ws und Timer
    # Datenbankverbindung wiederverwenden
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      @db_connection = connection
    end
  end

  # Startet den WebSocket-Service
  def start
    LOGGER.info "🚀 Starte Binance Websocket-Service für #{@pairs.length} Paare..."
    connect_and_subscribe # Baut die Verbindung auf und abonniert Streams
    keep_alive # Hält den Hauptthread am Laufen
  end

  private

  # Baut die WebSocket-Verbindung auf und abonniert die Streams.
  def connect_and_subscribe
    # Erstelle Stream-Namen für alle Paare (z.B. "btcusdc@kline_1m")
    stream_names = @pairs.map { |p| "#{p}@kline_1m" }
    
    # WICHTIG: Korrekte URL-Formatierung für Multi-Streams bei Binance
    # Streams werden durch '/' getrennt, OHNE '?streams=' Query-Parameter am /ws-Endpunkt.
    combined_stream_url = "#{BINANCE_WS_BASE_URL}/#{stream_names.join('/')}"

    # DIES IST DIE ENTSCHEIDENDE ZEILE FÜR DEN KONTEXT:
    # Wir speichern eine Referenz auf die aktuelle Instanz (BinanceWebsocketService)
    # BEVOR der Block für `on :open` etc. definiert wird.
    # Dadurch ist `service_instance_ref` im Closure-Scope dieser Blöcke verfügbar.
    service_instance_ref = self 

    @mutex.synchronize do # Schützt den Zugriff auf @ws
      LOGGER.info "🔗 Versuche Verbindung zu #{combined_stream_url} herzustellen..."
      
      # WebSocket::Client::Simple.connect gibt die Client-Instanz zurück, auf der die Callbacks registriert werden.
      # Diese Instanz verwaltet intern ihren eigenen Thread.
      @ws = WebSocket::Client::Simple.connect(combined_stream_url) do |ws_client_instance|
        # Callback für erfolgreiche Verbindung
        ws_client_instance.on :open do
          LOGGER.info "✅ WebSocket-Verbindung erfolgreich hergestellt!"
          # Nun können wir über `service_instance_ref` auf die Methoden und Instanzvariablen zugreifen.
          service_instance_ref.instance_variable_set(:@reconnect_attempt, 0) # Instanzvariable direkt setzen
          service_instance_ref.instance_variable_set(:@last_pong_at, Time.now) # Zeit des letzten Pongs/Datenempfangs zurücksetzen
          service_instance_ref.send(:start_ping_pong_timers) # Private Methode über `send` aufrufen
          service_instance_ref.send(:subscribe_to_all_klines) # (Optional) explizite Subscriptions senden
        end

        # Callback für empfangene Nachrichten
        ws_client_instance.on :message do |msg|
          # NEUE DEBUG-AUSGABE HIER: Prüfen, ob dieser Callback überhaupt erreicht wird.
          # LOGGER.info "📨 Nachricht empfangen (Typ: #{msg.type}): #{msg.data[0..100]}..."
          
          # Jede empfangene Nachricht (egal ob Daten oder Pong-Frame) bestätigt die Lebendigkeit der Verbindung.
          service_instance_ref.instance_variable_set(:@last_pong_at, Time.now)
          service_instance_ref.send(:cancel_pong_timeout_timer) # Den Pong-Timeout-Timer abbrechen

          # Besondere Behandlung für den "Pong timeout..." Nachrichtentyp, der als :close kommt
          if msg.type == :close && msg.data == "Pong timeout" # Genau prüfen
            LOGGER.warn "⚠️ Pong-Timeout erkannt - Verbindung wird geschlossen"
            # Hier keine weitere Verarbeitung, da dies ein internes Signal ist, das zur Schließung führt.
            return
          end

          service_instance_ref.send(:handle_message, msg) # Nachricht verarbeiten
        end

        # Callback für geschlossene Verbindung
        ws_client_instance.on :close do |e|
          LOGGER.warn "🔴 WebSocket-Verbindung geschlossen (Code: #{e.code}, Grund: #{e.reason})"
          service_instance_ref.send(:stop_ping_pong_timers) # Timer stoppen
          service_instance_ref.send(:reconnect) # Automatischer Reconnect
        end

        # Callback für WebSocket-Fehler
        ws_client_instance.on :error do |e|
          LOGGER.error "❌ WebSocket-Fehler: #{e.class} - #{e.message}"
          service_instance_ref.send(:stop_ping_pong_timers) # Timer stoppen
          service_instance_ref.send(:reconnect) # Automatischer Reconnect
        end
      end
    end
  end

  # Sendet explizite SUBSCRIBE-Nachrichten für alle Paare.
  # Dies ist primär nützlich, wenn man die Streams nicht direkt in der URL spezifiziert.
  # Bei Binance mit '/' in der URL ist es oft nicht nötig, aber eine gute Praxis.
  private def subscribe_to_all_klines
    # Die Streams sind bereits in der URL definiert.
    # Falls man nachträglich abonnieren will, würde man dies hier tun:
    # @pairs.each do |pair|
    #   subscribe_message = {
    #     method: "SUBSCRIBE",
    #     params: ["#{pair}@kline_1m"],
    #     id: Time.now.to_i + rand(1000) # Eindeutige ID für die Anfrage
    #   }.to_json
    #   @ws.send(subscribe_message)
    #   LOGGER.debug "Abonniert: #{pair}@kline_1m"
    # end
  end

  # Startet die Ping- und Pong-Timeout-Timer.
  private def start_ping_pong_timers
    stop_ping_pong_timers # Sicherstellen, dass keine alten Timer laufen

    # Ping-Timer: Sendet regelmäßig Pings
    @ping_timer = Concurrent::TimerTask.new(execution_interval: PING_INTERVAL_SECONDS) do
      @mutex.synchronize do # Schützt den Zugriff auf @ws
        if @ws && @ws.open?
          LOGGER.debug "Sende WebSocket-Ping..."
          @ws.ping # Sendet einen echten WebSocket-Ping-Frame (Protokoll-Level)
          start_pong_timeout_timer # Startet den Timeout-Timer für die Pong-Antwort
        else
          LOGGER.warn "Kann Ping nicht senden: WebSocket nicht offen. Timer wird gestoppt."
          stop_ping_pong_timers # Wenn WS nicht offen, Timer stoppen
        end
      end
    end
    @ping_timer.execute # Timer starten
    LOGGER.debug "Ping-Timer gestartet."
  end

  # Startet den Pong-Timeout-Timer.
  private def start_pong_timeout_timer
    cancel_pong_timeout_timer # Alten Timer abbrechen, falls vorhanden

    @pong_timeout_timer = Concurrent::TimerTask.new(execution_interval: PONG_TIMEOUT_SECONDS, run_now: false) do
      @mutex.synchronize do # Schützt den Zugriff auf @last_pong_at und @ws
        # Prüfen, ob wirklich keine Nachricht empfangen wurde seit dem letzten Ping
        if (Time.now - @last_pong_at) > PONG_TIMEOUT_SECONDS
          LOGGER.warn "Pong-Timeout! Keine Daten oder Pong seit #{PONG_TIMEOUT_SECONDS} Sekunden erhalten."
          LOGGER.warn "Verbindung wird als inaktiv betrachtet. Schließe Verbindung."
          @ws.close if @ws && @ws.open? # Schließe die Verbindung, um einen Reconnect auszulösen
        else
          LOGGER.debug "Pong-Timeout-Timer ausgelöst, aber Daten empfangen. Timer wird beim nächsten Ping neu gestartet."
        end
      end
    end
    @pong_timeout_timer.execute # Timer starten
    LOGGER.debug "Pong-Timeout-Timer gestartet."
  end

  # Bricht den Pong-Timeout-Timer ab.
  private def cancel_pong_timeout_timer
    if @pong_timeout_timer && @pong_timeout_timer.running?
      @pong_timeout_timer.shutdown # Timer sauber beenden
      @pong_timeout_timer = nil
      LOGGER.debug "Pong-Timeout-Timer abgebrochen."
    end
  end

  # Stoppt alle Ping/Pong-Timer.
  private def stop_ping_pong_timers
    if @ping_timer && @ping_timer.running?
      @ping_timer.shutdown # Ping-Timer sauber beenden
      @ping_timer = nil
      LOGGER.debug "Ping-Timer gestoppt."
    end
    cancel_pong_timeout_timer # Sicherstellen, dass auch der Pong-Timeout-Timer gestoppt wird
  end
  # --- Ende Ping/Pong-Logik ---

  # --- Reconnect-Logik ---
  # Versucht, die Verbindung neu aufzubauen mit exponentiellem Backoff.
  private def reconnect
    @mutex.synchronize do # Schützt den Reconnect-Prozess
      @reconnect_attempt += 1
      # Exponentieller Backoff mit maximaler Verzögerung
      reconnect_delay = [RECONNECT_INITIAL_DELAY_SECONDS * (2**(@reconnect_attempt - 1)), RECONNECT_MAX_DELAY_SECONDS].min
      LOGGER.info "Versuche Neuverbindung in #{reconnect_delay} Sekunden (Versuch #{@reconnect_attempt})..."
      
      # Starte den Reconnect-Versuch in einem neuen Thread, um den aktuellen Callback nicht zu blockieren.
      Thread.new do
        sleep reconnect_delay
        connect_and_subscribe # Rekursiver Aufruf zum Neuverbinden
      end
    end
  end
  # --- Ende Reconnect-Logik ---

  # Verarbeitet eingehende WebSocket-Nachrichten.
  private def handle_message(msg)
    # LOGGER.info "🔄 Verarbeite Nachricht: #{msg.data[0..80]}..."
    
    # Prüfen, ob es sich um gültige JSON-Daten handelt
    return unless msg.data.start_with?('{') || msg.data.start_with?('[')
    
    begin
      data = JSON.parse(msg.data)
      # LOGGER.info "✅ JSON geparst - Event: #{data['e']}"
      
      # Verarbeite verschiedene Event-Typen
      case data['e']
      when 'kline'
        process_kline_data(data['s'], data['k'])
      when '24hrTicker'
        process_ticker_data(data)
      else
        LOGGER.debug "❓ Unbekannter Event-Typ: #{data['e']}"
      end
    rescue JSON::ParserError => e
      LOGGER.warn "⚠️ JSON-Parsing-Fehler: #{e.message}"
    rescue => e
      LOGGER.error "❌ Fehler bei Nachrichtenverarbeitung: #{e.class} - #{e.message}"
    end
  end

  # Verarbeitet Daten aus einem Multi-Stream (Daten sind unter dem 'data'-Schlüssel)
  private def process_stream_data(data)
    LOGGER.debug "In process_stream_data. Event-Typ: #{data['e']}" # Debug-Log
    if data['e'] == 'kline' && data['k']
      process_kline_data(data['s'], data['k'])
    end
    # Hier können weitere Datentypen aus dem Multi-Stream verarbeitet werden
  end

  # Verarbeitet Kline-Daten (O, H, L, C, V)
  private def process_kline_data(symbol, kline)
    # LOGGER.debug "In process_kline_data für #{symbol}. Ist abgeschlossen: #{kline['x']}" # Debug-Log
    # Nur abgeschlossene Kerzen speichern, um Duplikate und unvollständige Daten zu vermeiden
    if kline['x'] # 'x' ist true für abgeschlossene Kerzen
      save_kline(symbol, kline)
    end
  rescue StandardError => e
    LOGGER.error "Fehler beim Verarbeiten/Speichern der Kline für #{symbol}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
  end

  # Speichert die Kline-Daten in der Datenbank.
  private def save_kline(symbol, kline)
    # LOGGER.info "💾 Speichere Kline für #{symbol}..."
    
    # Verwende die wiederverwendete Datenbankverbindung
    ActiveRecord::Base.connection_pool.with_connection do
      # Typkonvertierung und Mapping
      cryptocurrency = Cryptocurrency.find_by(symbol: symbol)
      unless cryptocurrency
        # LOGGER.info "🆕 Erstelle neue Kryptowährung: #{symbol}"
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
      # LOGGER.info "📊 [#{attrs[:timestamp].strftime('%H:%M:%S')}] #{symbol} O:#{attrs[:open]} H:#{attrs[:high]} L:#{attrs[:low]} C:#{attrs[:close]} V:#{attrs[:volume]}"
    end
  rescue => e
    LOGGER.error "❌ Fehler beim Speichern der Kline für #{symbol}: #{e.class} - #{e.message}"
  end

  # Hält den Hauptthread am Laufen, damit die Hintergrund-Threads arbeiten können.
  def keep_alive
    LOGGER.info "Service läuft... (Ctrl+C zum Beenden)"
    trap('INT') do
      LOGGER.info "\nBeende Service..."
      @mutex.synchronize do
        # Sicherstellen, dass die WebSocket-Verbindung sauber geschlossen wird
        @ws&.close if @ws && @ws.open?
      end
      stop_ping_pong_timers # Alle Timer stoppen
      exit 0 # Skript beenden
    end
    
    # Der Hauptthread blockiert hier auf unbestimmte Zeit.
    # Dies ist notwendig, damit die internen Threads von websocket-client-simple
    # und Concurrent::TimerTask-Threads im Hintergrund weiterlaufen können.
    loop do
      sleep 1 # Reduziert die CPU-Auslastung des Hauptthreads
    end
  end
end

# --- Skript-Ausführung ---
# Dieser Block wird nur ausgeführt, wenn das Skript direkt gestartet wird.
if __FILE__ == $0
  begin
    pairs = PairSelector.load_pairs # Handelspaare laden
    if pairs.empty?
      LOGGER.warn "Keine gültigen Paare zum Abonnieren gefunden! Skript wird beendet."
      exit 1
    end
    # Erstelle eine Instanz des Service mit den geladenen Paaren
    binance_service = BinanceWebsocketService.new(pairs)
    binance_service.start # Starte den Service
  rescue StandardError => e
    LOGGER.fatal "❌ Schwerwiegender Fehler beim Starten des Services: #{e.class} - #{e.message}"
    LOGGER.fatal e.backtrace.join("\n") # Detaillierten Stacktrace protokollieren
    exit 1
  end
end