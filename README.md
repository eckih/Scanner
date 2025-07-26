# Crypto Scanner

Ein Rails-basierter Kryptowährungs-Scanner mit Echtzeit-Preis-Updates über ActionCable/WebSockets.

## 🚀 Features

- **Echtzeit-Preis-Updates** über ActionCable/WebSockets
- **Live-Market-Cap-Daten** von CoinGecko API
- **24h-Preisänderungen** mit automatischer Berechnung
- **Docker-Containerisierung** mit PostgreSQL
- **Optimierte Performance** mit konfigurierbaren Debug-Schaltern

## 🔧 Debug-Schalter

Das System verfügt über konfigurierbare Debug-Schalter, um die Logging-Performance zu optimieren:

### Umgebungsvariablen

```bash
# Debug-Modus (detaillierte Logs)
DEBUG_MODE=true
VERBOSE_LOGGING=true

# Produktions-Modus (minimale Logs)
DEBUG_MODE=false
VERBOSE_LOGGING=false
```

### Docker Compose Konfiguration

```yaml
environment:
  - DEBUG_MODE=false      # Debug-Logs deaktivieren
  - VERBOSE_LOGGING=false # Verbose-Logs deaktivieren
```

### Logging-Level

- **DEBUG_MODE=true**: Zeigt alle Debug-Logs (Echtzeit-Broadcasts, Ping/Pong, etc.)
- **VERBOSE_LOGGING=true**: Zeigt detaillierte Info-Logs (Kline-Speicherung, Market Cap Updates)
- **Beide false**: Nur kritische Fehler und wichtige Status-Updates
- **Rails-interne Logs**: Werden automatisch reduziert (ActiveRecord Query Logs, ActionCable Broadcasting)

### Performance-Optimierung

Bei hoher Last empfehlen wir:
```yaml
environment:
  - DEBUG_MODE=false
  - VERBOSE_LOGGING=false
```

Für Entwicklung/Debugging:
```yaml
environment:
  - DEBUG_MODE=true
  - VERBOSE_LOGGING=true
```

### Rails-Logging-Optimierung

Das System reduziert automatisch:
- **ActiveRecord Query Logs** (`Cryptocurrency Load`) - gesteuert durch `DEBUG_MODE`
- **ActionCable Broadcasting Logs** - gesteuert durch `VERBOSE_LOGGING`
- **Rails Debug-Level Logs** - gesteuert durch `VERBOSE_LOGGING`

## 🐳 Docker Setup

### Voraussetzungen

- Docker
- Docker Compose

### Installation

1. **Repository klonen:**
```bash
git clone <repository-url>
cd scanner
```

2. **Container starten:**
```bash
docker compose up --build -d
```

3. **Datenbank einrichten:**
```bash
docker compose exec web bundle exec bin/rails db:create
docker compose exec web bundle exec bin/rails db:migrate
```

4. **Crypto History Tabelle erstellen:**
```bash
docker compose exec web bundle exec bin/rails r "ActiveRecord::Base.connection.execute(File.read('db/migrate/20241223_create_crypto_history_data_manual_postgresql.sql'))"
```

### Anwendung starten

Die Anwendung ist verfügbar unter: **http://localhost:3005**

## 📊 Features

### Echtzeit-Preis-Updates
- WebSocket-Verbindung zu Binance
- Sofortige Preis-Updates ohne Seiten-Reload
- ActionCable-Broadcasts an Frontend

### Market Cap Integration
- Automatische Updates von CoinGecko API
- Alle 5 Minuten Market Cap und Rank Updates
- Korrekte Market Cap Berechnung (Preis × Circulating Supply)

### 24h-Preisänderungen
- Automatische Berechnung bei abgeschlossenen Kerzen
- Fallback auf älteste verfügbare Daten
- Visuelle Kennzeichnung unvollständiger Daten

### Datenbank-Optimierung
- PostgreSQL für bessere Multi-Threading-Unterstützung
- Optimierte Connection Pool Konfiguration
- 20 gleichzeitige Datenbankverbindungen

## 🔍 Troubleshooting

### Debug-Schalter aktivieren
```bash
# Container mit Debug-Modus neu starten
docker compose down
docker compose up -d
```

### Logs überprüfen
```bash
# Web-Container Logs
docker compose logs web --tail=50

# Datenbank-Container Logs
docker compose logs db --tail=20
```

### Datenbank-Status
```bash
# PostgreSQL-Verbindung testen
docker compose exec web bundle exec bin/rails db:version
```

## 📝 Entwicklung

### Debug-Modus aktivieren
```yaml
# docker-compose.yml
environment:
  - DEBUG_MODE=true
  - VERBOSE_LOGGING=true
```

### Logs filtern
```bash
# Nur Debug-Logs
docker compose logs web | grep "DEBUG"

# Nur Fehler
docker compose logs web | grep "ERROR"
```

## 🎯 Performance-Tipps

1. **Debug-Schalter deaktivieren** für Produktionsumgebung
2. **Log-Rotation** konfigurieren für große Log-Dateien
3. **Connection Pool** an Workload anpassen
4. **Market Cap Updates** auf längere Intervalle setzen bei hoher Last

## 📈 Monitoring

### Wichtige Metriken
- WebSocket-Verbindungsstatus
- Datenbankverbindungen
- ActionCable-Broadcast-Rate
- Market Cap Update-Frequenz

### Log-Monitoring
```bash
# Echtzeit-Logs
docker compose logs -f web

# Fehler-Monitoring
docker compose logs web | grep -i error
```