# Krypto Scanner

Eine Ruby on Rails Anwendung zur Anzeige der Top 50 Kryptowährungen mit Market Cap und RSI-Indikatoren. Die App läuft in einer Docker-Compose Umgebung mit SQLite-Datenbank.

## Features

- **Top 50 Kryptowährungen**: Anzeige der größten Kryptowährungen nach Market Cap
- **Echtzeitdaten**: Daten von CoinGecko API mit Freqtrade Integration
- **RSI-Indikatoren**: Relative Strength Index für Trading-Signale
- **Responsive Design**: Optimiert für Desktop und Mobile
- **Automatische Updates**: Daten können manuell aktualisiert werden

## Technologie-Stack

- **Ruby on Rails 7.0**
- **SQLite3** Datenbank
- **Docker & Docker Compose**
- **Bootstrap 5** für UI
- **HTTParty** für API-Aufrufe
- **CoinGecko API** für Marktdaten

## Installation und Setup

### Voraussetzungen

- Docker
- Docker Compose

### Schritt 1: Repository klonen

```bash
git clone <repository-url>
cd Scanner
```

### Schritt 2: Umgebungsvariablen (Optional)

Erstellen Sie eine `.env` Datei für Freqtrade API-Konfiguration:

```bash
FREQTRADE_API_URL=http://localhost:8080
FREQTRADE_API_TOKEN=your_api_token_here
```

### Schritt 3: Docker Container starten

```bash
docker-compose up --build
```

Die Anwendung ist dann unter `http://localhost:3000` verfügbar.

## Verwendung

### Dashboard

- Besuchen Sie `http://localhost:3000` für das Haupt-Dashboard
- Zeigt die Top 50 Kryptowährungen sortiert nach Market Cap
- Responsive Tabelle für Desktop, Karten-Layout für Mobile

### Daten aktualisieren

- Klicken Sie auf "Daten aktualisieren" um die neuesten Kurse zu laden
- Daten werden automatisch beim ersten Besuch geladen

### RSI-Indikatoren

- **Grün (≤ 30)**: Überverkauft - Potentieller Kaufsignal
- **Gelb (31-69)**: Neutral - Normale Marktbedingungen  
- **Rot (≥ 70)**: Überkauft - Potentieller Verkaufssignal

## API-Integration

### CoinGecko API

Die App verwendet die kostenlose CoinGecko API für:
- Aktuelle Preise
- Market Cap Daten
- 24h Preisänderungen
- Handelsvolumen

### Freqtrade API (Optional)

Für erweiterte Trading-Daten können Sie Ihre Freqtrade-Instanz verbinden:
- RSI-Berechnungen aus echten Candlestick-Daten
- Trading-Pair Informationen
- Historische Daten

## Entwicklung

### Lokale Entwicklung

```bash
# Dependencies installieren
bundle install

# Datenbank erstellen und migrieren
rails db:create db:migrate

# Server starten
rails server
```

### Neue Features hinzufügen

1. Modelle in `app/models/`
2. Controller in `app/controllers/`
3. Views in `app/views/`
4. Services in `app/services/`

### Datenbank-Migrationen

```bash
# Neue Migration erstellen
rails generate migration AddColumnToCryptocurrencies

# Migration ausführen
rails db:migrate
```

## Deployment

### Production Setup

1. Umgebungsvariablen für Production setzen
2. Assets precompilieren
3. Datenbank migrieren

```bash
RAILS_ENV=production rails assets:precompile
RAILS_ENV=production rails db:migrate
```

## Troubleshooting

### Häufige Probleme

1. **API-Fehler**: Überprüfen Sie Ihre Internetverbindung
2. **Docker-Probleme**: `docker-compose down && docker-compose up --build`
3. **Datenbank-Fehler**: `docker-compose exec web rails db:reset`

### Logs anzeigen

```bash
# Container-Logs
docker-compose logs web

# Rails-Logs
docker-compose exec web tail -f log/development.log
```

## Lizenz

MIT License

## Beitragen

1. Fork das Repository
2. Erstellen Sie einen Feature-Branch
3. Committen Sie Ihre Änderungen
4. Erstellen Sie einen Pull Request

## Support

Bei Fragen oder Problemen erstellen Sie bitte ein Issue im Repository. 