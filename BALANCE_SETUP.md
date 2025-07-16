# Balance-Feature Setup

## Übersicht
Das Balance-Feature ermöglicht es, die Binance-Kontostände zu verfolgen und als fortlaufende Graphen anzuzeigen.

## Setup-Anleitung

### 1. Umgebungsvariablen einrichten
Erstelle eine `.env` Datei im Scanner-Verzeichnis mit folgenden Variablen:

```env
# Binance API Credentials
BINANCE_API_KEY=your_binance_api_key_here
BINANCE_API_SECRET=your_binance_api_secret_here

# Weitere Konfiguration falls nötig
RAILS_ENV=development
```

### 2. Binance API-Schlüssel erstellen
1. Melde dich in deinem Binance-Konto an
2. Gehe zu "API Management" 
3. Erstelle einen neuen API-Schlüssel
4. **WICHTIG**: Gib dem API-Schlüssel nur **READ-Berechtigung** für Sicherheit
5. Kopiere den API-Schlüssel und das Secret in die `.env` Datei

### 3. Datenbank-Migration ausführen
```bash
cd Scanner
bundle install
rails db:migrate
```

### 4. Balance-Daten laden
Nach dem Start der Rails-App:
1. Gehe zu `/balances`
2. Klicke auf "Daten aktualisieren"
3. Die Balance-Daten werden von der Binance API geladen

## Features
- **Gesamt-Balance**: Zeigt die gesamte Balance in USD und BTC
- **Asset-Details**: Übersicht über alle Assets mit Balance > 0
- **Fortlaufende Graphen**: Zeigt die Balance-Entwicklung über Zeit
- **Auto-Refresh**: Automatische Aktualisierung der Charts
- **Verschiedene Zeiträume**: 6h, 12h, 24h, 3 Tage, 1 Woche

## Sicherheitshinweise
- Verwende nur API-Schlüssel mit READ-Berechtigung
- Teile die `.env` Datei niemals mit anderen
- Die `.env` Datei ist bereits in `.gitignore` enthalten

## Fehlerbehandlung
Falls Fehler auftreten:
1. Überprüfe die API-Schlüssel in der `.env` Datei
2. Stelle sicher, dass die API-Schlüssel aktiv sind
3. Überprüfe die Netzwerkverbindung zu Binance
4. Schaue in die Rails-Logs für weitere Details 