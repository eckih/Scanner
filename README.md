# Krypto Scanner

Eine Ruby on Rails-Anwendung zur Anzeige der Top-Kryptowährungen mit Marktkapitalisierung und RSI-Daten von der Binance API.

## Features

- **Live-Daten von Binance API**: Aktuelle Kurse und RSI-Werte direkt von Binance
- **Top 50 Kryptowährungen**: Anzeige der wichtigsten Kryptowährungen
- **RSI-Indikator**: Relative Strength Index für technische Analyse
- **Sortierbare Tabelle**: DataTables-Integration für Sortierung und Suche
- **Responsive Design**: Bootstrap 5 für moderne UI
- **Docker-Support**: Vollständige Containerisierung

## Technologie-Stack

- **Backend**: Ruby on Rails 7.1
- **Datenbank**: SQLite3
- **Frontend**: Bootstrap 5, jQuery, DataTables
- **API**: Binance REST API
- **Container**: Docker & Docker Compose

## Installation

1. Repository klonen:
```bash
git clone <repository-url>
cd Scanner
```

2. Mit Docker starten:
```bash
docker-compose up
```

Die Anwendung ist dann unter `http://localhost:3000` verfügbar.

## API-Integration

### Binance API

Die Anwendung nutzt die öffentliche Binance REST API:

- **Preise**: `/api/v3/ticker/price` - Aktuelle Kurse aller Handelspaare
- **Klines**: `/api/v3/klines` - Historische Daten für RSI-Berechnung
- **Exchange Info**: `/api/v3/exchangeInfo` - Verfügbare Handelspaare

### Verfügbare Rake Tasks

```bash
# Top 50 Kryptowährungen abrufen (empfohlen)
docker-compose run web rake binance:fetch_top_50

# Alle verfügbaren Kryptowährungen abrufen (dauert länger)
docker-compose run web rake binance:fetch_all_cryptos

# Datenbank leeren
docker-compose run web rake binance:clear_data
```

## RSI-Berechnung

Der Relative Strength Index (RSI) wird basierend auf 1-Stunden-Klines berechnet:

- **Periode**: 14 (Standard)
- **Datenquelle**: Binance Klines API
- **Algorithmus**: Smoothed RSI nach Wilder

### RSI-Interpretation

- **RSI < 30**: Überverkauft (grün)
- **RSI > 70**: Überkauft (rot)
- **RSI 30-70**: Neutral (gelb)

## Datenaktualisierung

### Automatisch
- Beim ersten Laden der Seite werden automatisch die Top 10 Kryptowährungen geladen

### Manuell
- **Web-Interface**: "Daten aktualisieren" Button in der Navigation
- **Rake Task**: `rake binance:fetch_top_50`

## Entwicklung

### Lokale Entwicklung

```bash
# Container starten
docker-compose up

# Rake Tasks ausführen
docker-compose run web rake binance:fetch_top_50

# Rails Console
docker-compose run web rails console

# Tests ausführen
docker-compose run web rails test
```

### Service-Architektur

- **BinanceService**: Hauptservice für API-Aufrufe
  - `fetch_and_update_all_cryptos`: Alle verfügbaren Kryptowährungen
  - `fetch_specific_cryptos(symbols)`: Spezifische Symbole
  - `calculate_rsi_for_symbol(symbol)`: RSI-Berechnung

### Datenbank-Schema

```ruby
# Cryptocurrency Model
class Cryptocurrency < ApplicationRecord
  # Attribute:
  # - symbol: String (z.B. "BTC")
  # - name: String (z.B. "Bitcoin")
  # - current_price: Decimal
  # - market_cap: Decimal
  # - market_cap_rank: Integer
  # - rsi: Decimal
  # - updated_at: DateTime
end
```

## Rate Limits

Die Anwendung berücksichtigt Binance API Rate Limits:

- **Pause zwischen Anfragen**: 0.1 Sekunden
- **Batch-Verarbeitung**: Preise werden in einem Aufruf abgerufen
- **Fehlerbehandlung**: Automatische Wiederholung bei Fehlern

## Deployment

### Produktionsumgebung

1. Umgebungsvariablen setzen:
```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=<your-secret-key>
```

2. Container für Produktion bauen:
```bash
docker-compose -f docker-compose.prod.yml up
```

## Troubleshooting

### Häufige Probleme

1. **API-Fehler**: Überprüfen Sie die Internetverbindung und Binance API-Status
2. **Leere Tabelle**: Führen Sie `rake binance:fetch_top_50` aus
3. **Docker-Probleme**: `docker-compose down && docker-compose up --build`

### Logs

```bash
# Container-Logs anzeigen
docker-compose logs web

# Live-Logs verfolgen
docker-compose logs -f web
```

## Lizenz

MIT License 