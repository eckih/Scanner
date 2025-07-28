# 🚀 Crypto Scanner - Kryptowährungs-Trading Scanner

Ein Rails-basierter Kryptowährungs-Scanner mit Echtzeit-Preisüberwachung, RSI-Berechnung und WebSocket-Integration für Binance.

## 📋 Inhaltsverzeichnis

- [Installation](#installation)
- [Verfügbare Tasks](#verfügbare-tasks)
- [Webinterface](#webinterface)
- [Datenbank-Admin](#datenbank-admin)
- [Konfiguration](#konfiguration)

## 🛠️ Installation

### Voraussetzungen
- Docker & Docker Compose
- Git

### Setup
```bash
# Repository klonen
git clone <repository-url>
cd Scanner

# Container starten
docker compose up -d

# Datenbank einrichten
docker compose exec web bin/rails db:create db:migrate

# Komplette Einrichtung (empfohlen)
docker compose exec web bin/rails crypto:setup_complete_v2
```

## 📊 Verfügbare Tasks

### 🚀 Setup & Einrichtung

#### `crypto:setup_complete_v2`
**Komplette Einrichtung aller Komponenten**
```bash
docker compose exec web bin/rails crypto:setup_complete_v2
```
- Synchronisiert Datenbank mit bot.json Whitelist
- Lädt historische Daten für alle Pairs (letzte 2 Tage)
- Berechnet RSI für alle Timeframes
- Zeigt finale Statistiken

#### `crypto:sync_whitelist`
**Synchronisiert Datenbank mit bot.json**
```bash
docker compose exec web bin/rails crypto:sync_whitelist
```
- Entfernt nicht-whitelistierte Kryptowährungen
- Fügt fehlende Whitelist-Pairs hinzu
- Löscht zugehörige historische Daten

#### `crypto:fix_symbol_format`
**Standardisiert Kryptowährungs-Symbole**
```bash
docker compose exec web bin/rails crypto:fix_symbol_format
```
- Konvertiert "BTCUSDC" zu "BTC/USDC"
- Entfernt Duplikate
- Standardisiert alle Symbole

#### `crypto:cleanup_database`
**Bereinigt die Datenbank**
```bash
docker compose exec web bin/rails crypto:cleanup_database
```
- Entfernt alle nicht-whitelistierten Pairs
- Löscht zugehörige historische Daten
- Behält nur Whitelist-Pairs

### 📈 Daten laden

#### `crypto:load_all_whitelist_data`
**Lädt historische Daten für alle Whitelist-Pairs**
```bash
docker compose exec web bin/rails crypto:load_all_whitelist_data
```
- Lädt Daten der letzten 2 Tage
- 5 Timeframes: 1m, 5m, 15m, 1h, 4h
- Berechnet RSI für alle Timeframes
- Aktualisiert aktuelle Preise

#### `crypto:load_historical_data`
**Lädt historische Daten für alle Kryptowährungen**
```bash
docker compose exec web bin/rails crypto:load_historical_data
```
- Lädt Daten für alle verfügbaren Pairs
- Verschiedene Timeframes
- Speichert OHLCV-Daten

#### `crypto:load_whitelist_pairs`
**Lädt nur Whitelist-Pairs in die Datenbank**
```bash
docker compose exec web bin/rails crypto:load_whitelist_pairs
```
- Erstellt Kryptowährungen aus bot.json
- Lädt aktuelle Preise von Binance
- Aktualisiert Market Cap Daten

#### `crypto:load_newt_data`
**Lädt speziell NEWT/USDT Daten**
```bash
docker compose exec web bin/rails crypto:load_newt_data
```
- Lädt NEWT/USDT Daten der letzten 2 Tage
- Alle Timeframes
- RSI-Berechnung

#### `crypto:load_current_prices`
**Lädt aktuelle Preise von Binance**
```bash
docker compose exec web bin/rails crypto:load_current_prices
```
- Aktualisiert Preise für Whitelist-Pairs
- 24h Preisänderungen
- Handelsvolumen

### 📊 RSI & Indikatoren

#### `crypto:calculate_rsi_now`
**Berechnet RSI für alle Kryptowährungen**
```bash
docker compose exec web bin/rails crypto:calculate_rsi_now
```
- Berechnet RSI für alle verfügbaren Pairs
- Verschiedene Timeframes
- Speichert RSI-Historie

#### `crypto:test_rsi_calculation`
**Testet und debuggt RSI-Berechnung**
```bash
docker compose exec web bin/rails crypto:test_rsi_calculation
```
- Zeigt detaillierte RSI-Berechnung
- Vergleicht manuelle vs. Service-Berechnung
- Debug-Informationen für alle Timeframes

### 🔧 Wartung & Debugging

#### `crypto:setup_complete`
**Legacy Setup-Task**
```bash
docker compose exec web bin/rails crypto:setup_complete
```
- Führt sync_whitelist und calculate_rsi_now aus
- Ältere Version des Setup-Tasks

## 🌐 Webinterface

### Hauptanwendung
```
http://localhost:3005/cryptocurrencies
```
- Echtzeit-Preisüberwachung
- RSI-Anzeige mit Farbkodierung
- Timeframe-Wechsel
- Live-Updates über WebSocket

### Datenbank-Admin (Adminer)
```
http://localhost:3006
```
**Login-Daten:**
- System: PostgreSQL
- Server: db
- Benutzer: scanner_user
- Passwort: scanner_password
- Datenbank: scanner_development

## ⚙️ Konfiguration

### bot.json
```json
{
  "exchange": {
    "pair_whitelist": [
      "BTC/USDC", "ETH/USDC", "BNB/USDC", 
      "ADA/USDC", "SOL/USDC", "NEWT/USDC"
    ],
    "pair_blacklist": []
  }
}
```

### Umgebungsvariablen
   ```bash
RAILS_ENV=development
DATABASE_URL=postgresql://scanner_user:scanner_password@db:5432/scanner_development
DEBUG_MODE=true
VERBOSE_LOGGING=true
```

## 📊 Verfügbare Daten

### Kryptowährungen
- **BTC/USDC** - Bitcoin
- **ETH/USDC** - Ethereum
- **BNB/USDC** - Binance Coin
- **ADA/USDC** - Cardano
- **SOL/USDC** - Solana
- **NEWT/USDC** - Newton Project

### Timeframes
- **1m** - 1 Minute
- **5m** - 5 Minuten
- **15m** - 15 Minuten
- **1h** - 1 Stunde
- **4h** - 4 Stunden

### Indikatoren
- **RSI** - Relative Strength Index (Periode 14)
- **Preisänderung 24h**
- **Handelsvolumen**
- **Market Cap**

## 🔄 Live-Updates

### WebSocket-Integration
- Echtzeit-Preisupdates von Binance
- ActionCable-Broadcasting
- Automatische RSI-Berechnung
- Live-Tabellen-Updates

### Background-Jobs
- RsiCalculationJob
- BalanceUpdateJob
- CryptocurrencyUpdateJob

## 🛠️ Entwicklung

### Container starten
```bash
docker compose up -d
```

### Logs anzeigen
```bash
docker compose logs -f web
```

### Rails Console
```bash
docker compose exec web bin/rails console
```

### Datenbank-Reset
```bash
docker compose exec web bin/rails db:reset
```

## 📝 Troubleshooting

### Häufige Probleme

**1. Container startet nicht**
```bash
docker compose down
docker compose up -d
```

**2. Datenbank-Verbindung**
```bash
docker compose exec web bin/rails db:create db:migrate
```

**3. RSI-Werte zeigen "N/A"**
```bash
docker compose exec web bin/rails crypto:load_all_whitelist_data
```

**4. WebSocket-Verbindung**
```bash
docker compose restart web
```

## 🚀 Deployment

### Production
```bash
# Umgebungsvariablen setzen
RAILS_ENV=production

# Assets kompilieren
docker compose exec web bin/rails assets:precompile

# Datenbank migrieren
docker compose exec web bin/rails db:migrate
```

## 📄 Lizenz

Dieses Projekt ist für Bildungs- und Entwicklungszwecke gedacht.

---

**Hinweis:** Dieser Scanner ist für Bildungszwecke entwickelt. Verwenden Sie ihn nicht für echtes Trading ohne gründliche Tests und Risikobewertung.


# Rails Console starten
```
docker compose exec -e RAILS_CONSOLE=true web bin/rails console
```