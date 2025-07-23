#!/usr/bin/env ruby
require 'websocket-client-simple'
require 'json'
require 'logger'

# Logger initialisieren, um alle Debug-Meldungen zu sehen
LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::DEBUG

# Verwenden Sie einen sehr aktiven Trade-Stream für den Test
BINANCE_TEST_URL = 'wss://stream.binance.com:9443/ws/btcusdt@trade'

puts "Versuche Verbindung zu #{BINANCE_TEST_URL} herzustellen..."

# Verbinde zum WebSocket
ws = WebSocket::Client::Simple.connect(BINANCE_TEST_URL)

# Callback für erfolgreiche Verbindung
ws.on :open do
  LOGGER.info "✅ Verbindung hergestellt."
end

# Callback für empfangene Nachrichten
ws.on :message do |msg|
  # Logge jede empfangene Nachricht, egal welchen Typs
  LOGGER.debug "Nachricht empfangen (Typ: #{msg.type}): #{msg.data[0..200]}..."

  if msg.type == :text # Wenn es eine Textnachricht ist (JSON)
    begin
      data = JSON.parse(msg.data)
      # Wenn es ein Trade-Event ist, logge Symbol und Preis
      if data['e'] == 'trade'
        LOGGER.info "Geparsed Trade: Symbol=#{data['s']}, Preis=#{data['p']}"
      else
        LOGGER.debug "Anderes JSON-Event: #{data['e']}"
      end
    rescue JSON::ParserError # Fange Fehler beim Parsen von Nicht-JSON-Text ab
      LOGGER.warn "Nicht-JSON-Textnachricht: #{msg.data[0..100]}..."
    end
  elsif msg.type == :pong # Wenn es ein Protokoll-Pong-Frame ist
    LOGGER.info "Echter WebSocket-Pong-Frame empfangen."
  end
end

# Callback für geschlossene Verbindung
ws.on :close do |e|
  LOGGER.warn "🔴 Verbindung geschlossen: Code=#{e.code}, Reason=#{e.reason}"
end

# Callback für Fehler
ws.on :error do |e|
  LOGGER.error "❌ Fehler: #{e.message}"
end

puts "Warte auf Nachrichten... (Ctrl+C zum Beenden)"
# Hält den Hauptthread am Leben, damit der WebSocket-Client im Hintergrund arbeiten kann
loop do
  sleep 1
end