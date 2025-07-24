# Kryptowährungs-Scanner - Ruby on Rails

Ein Echtzeit-Kryptowährungs-Scanner und Analyse-Tool, entwickelt mit Ruby on Rails, mit Multi-Zeitrahmen RSI-Analyse, interaktiven Charts und Live-Daten von der Binance API.

## Features

- 📊 **Echtzeit-Kryptowährungsdaten** - Live-Preise und Marktdaten von der Binance API
- 📈 **Multi-Zeitrahmen RSI-Analyse** - RSI-Indikatoren für 1m, 15m und 1h Zeitrahmen
- 🎯 **Interaktive Charts** - Dynamische Preis-Charts mit technischen Indikatoren
- 🔍 **Erweiterte Filterung** - Filterung nach RSI-Levels, Marktkapitalisierung und Volumen
- ⚡ **Hintergrund-Verarbeitung** - Automatische Datenaktualisierung mit Sidekiq
- 🐳 **Docker-Support** - Einfache Bereitstellung mit Docker und Docker Compose
- 🚀 **Produktionsbereit** - CI/CD-Pipeline mit GitHub Actions

## Screenshots

![Kryptowährungs-Scanner Dashboard](screenshot.png)

## Schnellstart

### Entwicklungsumgebung

1. **Repository klonen**
   ```bash
   git clone https://github.com/yourusername/cryptocurrency-scanner.git
   cd cryptocurrency-scanner
   ```

2. **Mit Docker (Empfohlen)**
   ```bash
   docker-compose up -d
   ```
   
   Die Anwendung ist dann unter http://localhost:3000 verfügbar

3. **Manuelle Installation**
   ```bash
   # Abhängigkeiten installieren
   bundle install
   
   # Datenbank einrichten
   rails db:create db:migrate db:seed
   
   # Server starten
   rails server
   ```

### Produktions-Deployment

Für die Produktions-Bereitstellung siehe unseren umfassenden [Deployment-Leitfaden](DEPLOYMENT.md).

#### Schnelle Produktions-Einrichtung

1. **Server-Anforderungen**
   - Ubuntu 20.04+ mit Docker und Docker Compose
   - 2GB RAM, 20GB Festplattenspeicher
   - Offene Ports: 22, 80, 443, 3000

2. **GitHub CI/CD Einrichtung**
   - GitHub Secrets konfigurieren (HOST, USERNAME, SSH_PRIVATE_KEY, SECRET_KEY_BASE)
   - Push zum main Branch löst automatisches Deployment aus

3. **Manuelles Deployment**
   ```bash
   # Auf Ihrem Server
   git clone https://github.com/yourusername/cryptocurrency-scanner.git /opt/cryptocurrency-scanner
   cd /opt/cryptocurrency-scanner
   chmod +x deploy.sh
   ./deploy.sh deploy
   ```

## Technologie-Stack

- **Backend**: Ruby on Rails 7.1
- **Datenbank**: SQLite (Entwicklung), PostgreSQL (produktionsbereit)
- **Cache/Jobs**: Redis + Sidekiq
- **Frontend**: Bootstrap 5, Chart.js, Stimulus
- **API**: Binance API für Kryptowährungsdaten
- **Deployment**: Docker, GitHub Actions, Nginx

## Architektur

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Rails App     │    │   Binance API   │
│   (Bootstrap)   │◄──►│   (Controllers) │◄──►│   (Live-Daten)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Hintergrund   │
                       │   Jobs (Sidekiq)│
                       └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Datenbank     │
                       │   (SQLite/PG)   │
                       └─────────────────┘
```

## API-Endpunkte

### REST API
- `GET /api/v1/cryptocurrencies` - Alle Kryptowährungen auflisten
- `GET /api/v1/cryptocurrencies/:id` - Spezifische Kryptowährung abrufen
- `GET /api/v1/cryptocurrencies/:id/chart_data` - Chart-Daten abrufen

### Health Check
- `GET /health` - Anwendungsstatus

## Konfiguration

### Umgebungsvariablen

```env
# Rails Konfiguration
RAILS_ENV=production
SECRET_KEY_BASE=ihr_secret_key
RAILS_LOG_TO_STDOUT=true

# Datenbank
DATABASE_URL=sqlite3:db/production.sqlite3

# Redis (für Caching und Hintergrund-Jobs)
REDIS_URL=redis://localhost:6379/0

# Binance API (optional)
BINANCE_API_KEY=ihr_api_key
BINANCE_API_SECRET=ihr_api_secret

# Server-Konfiguration
PORT=3000
WEB_CONCURRENCY=2
RAILS_MAX_THREADS=5
```

## Entwicklung

### Tests ausführen
```bash
bundle exec rspec
```

### Code-Qualität
```bash
bundle exec rubocop
bundle exec bundle audit
```

### Hintergrund-Jobs
```bash
# Sidekiq starten
bundle exec sidekiq

# Jobs überwachen
open http://localhost:4567/sidekiq
```

### Datenbank-Operationen
```bash
# Erstellen und migrieren
rails db:create db:migrate

# Mit Beispieldaten füllen
rails db:seed

# Datenbank zurücksetzen
rails db:reset
```

## Überwachung

### Health Checks
- Anwendung: `GET /health`
- Datenbank: Im Health Check enthalten
- Redis: Im Health Check enthalten

### Logs
```bash
# Anwendungs-Logs
tail -f log/production.log

# Docker-Logs
docker-compose logs -f

# Deployment-Script-Logs
./deploy.sh logs
```

### Performance-Überwachung
- Eingebaute Rails-Metriken
- Puma Worker-Überwachung
- Speicherverbrauch-Tracking
- Optional: New Relic, Scout APM

## Sicherheit

- Non-root Docker-Container
- Sichere Session-Konfiguration
- HTTPS-Support (mit Nginx)
- Regelmäßige Sicherheitsaudits
- Umgebungsvariablen-Schutz

## Mitwirken

1. Repository forken
2. Feature-Branch erstellen (`git checkout -b feature/tolles-feature`)
3. Änderungen committen (`git commit -m 'Tolles Feature hinzufügen'`)
4. Branch pushen (`git push origin feature/tolles-feature`)
5. Pull Request öffnen

## Deployment-Dateien

- `Dockerfile.production` - Produktions-Docker-Image
- `docker-compose.production.yml` - Produktions-Services
- `.github/workflows/deploy.yml` - CI/CD-Pipeline
- `deploy.sh` - Manuelles Deployment-Script
- `DEPLOYMENT.md` - Umfassender Deployment-Leitfaden

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe die [LICENSE](LICENSE) Datei für Details.

## Support

- 📖 [Deployment-Leitfaden](DEPLOYMENT.md)
- 🐛 [Issue-Tracker](https://github.com/yourusername/cryptocurrency-scanner/issues)
- 💬 [Diskussionen](https://github.com/yourusername/cryptocurrency-scanner/discussions)

---

**Mit ❤️ entwickelt mit Ruby on Rails** 


docker compose exec web rails runner "puts '=== ALL CRYPTOCURRENCIES ==='; Cryptocurrency.all.each { |c| puts \"#{c.id}. #{c.name} (#{c.symbol}) - Price: $#{c.current_price} - RSI: #{c.rsi} - ROC: #{c.roc} - ROC': #{c.roc_derivative} - Updated: #{c.updated_at}\" }"

docker compose exec web bash
bundle exec ruby bin/binance_websocket_service.rb

docker compose exec web ruby bin/binance_websocket_service.rb