# Krypto Scanner - Installationsanleitung

## Problem mit Docker Desktop

Falls Sie den Fehler `rpc error: code = Unavailable desc = error reading from server: EOF` erhalten, liegt das an einem Problem mit Docker Desktop. Hier sind verschiedene Lösungsansätze:

## Option 1: Docker Desktop reparieren

1. **Docker Desktop neu starten:**
   ```cmd
   # Docker Desktop über das System-Tray beenden
   # Docker Desktop als Administrator neu starten
   ```

2. **Docker Desktop zurücksetzen:**
   - Öffnen Sie Docker Desktop
   - Gehen Sie zu Settings → Troubleshoot
   - Klicken Sie auf "Reset to factory defaults"

3. **WSL2 Backend prüfen:**
   - Stellen Sie sicher, dass WSL2 aktiviert ist
   - In Docker Desktop Settings → General → "Use WSL 2 based engine"

## Option 2: Direkt mit Ruby (Empfohlen)

### Voraussetzungen installieren

1. **Ruby 3.2.8 installieren:**
   - Laden Sie Ruby von https://rubyinstaller.org/ herunter
   - Installieren Sie Ruby 3.2.8 mit DevKit

2. **Bundler installieren:**
   ```cmd
   gem install bundler
   ```

3. **SQLite3 installieren:**
   - Wird normalerweise mit Ruby mitgeliefert
   - Falls nicht: https://www.sqlite.org/download.html

### App starten

1. **Dependencies installieren:**
   ```cmd
   bundle install
   ```

2. **Datenbank erstellen:**
   ```cmd
   bundle exec rails db:create
   bundle exec rails db:migrate
   ```

3. **Server starten:**
   ```cmd
   bundle exec rails server
   ```

4. **App öffnen:**
   - Besuchen Sie http://localhost:3000

### Automatisches Skript verwenden

Alternativ können Sie das bereitgestellte Batch-Skript verwenden:
```cmd
start.bat
```

## Option 3: Docker ohne Docker Desktop

### Mit Docker CLI (falls installiert)

1. **Image bauen:**
   ```cmd
   docker build -t crypto-scanner .
   ```

2. **Container starten:**
   ```cmd
   docker run -p 3000:3000 -v %cd%:/app crypto-scanner
   ```

## Option 4: Alternative Container-Lösungen

### Mit Podman (Docker-Alternative)

1. **Podman installieren:**
   - https://podman.io/getting-started/installation

2. **Container starten:**
   ```cmd
   podman-compose up --build
   ```

## Troubleshooting

### Häufige Probleme

1. **Ruby nicht gefunden:**
   ```cmd
   # Prüfen Sie die Ruby-Installation
   ruby --version
   
   # Pfad zur Ruby-Installation hinzufügen
   set PATH=%PATH%;C:\Ruby32-x64\bin
   ```

2. **Bundle install Fehler:**
   ```cmd
   # Bundler neu installieren
   gem uninstall bundler
   gem install bundler
   
   # Cache löschen
   bundle clean --force
   bundle install
   ```

3. **SQLite3 Fehler:**
   ```cmd
   # SQLite3 Gem neu installieren
   gem uninstall sqlite3
   gem install sqlite3 --platform=ruby
   ```

4. **Port bereits belegt:**
   ```cmd
   # Anderen Port verwenden
   bundle exec rails server -p 3001
   ```

### Logs prüfen

```cmd
# Rails-Logs anzeigen
tail -f log/development.log

# Oder auf Windows
type log\development.log
```

## Entwicklungsumgebung

### Empfohlene Tools

1. **Code-Editor:**
   - Visual Studio Code mit Ruby-Extension
   - RubyMine

2. **Git:**
   - Git für Windows: https://git-scm.com/download/win

3. **API-Testing:**
   - Postman oder Insomnia für API-Tests

### Nützliche Commands

```cmd
# Datenbank zurücksetzen
bundle exec rails db:reset

# Console öffnen
bundle exec rails console

# Routes anzeigen
bundle exec rails routes

# Tests ausführen (falls vorhanden)
bundle exec rails test
```

## Produktions-Deployment

Für Production-Deployment empfehlen wir:

1. **Heroku:** Einfaches Deployment mit Git
2. **Railway:** Moderne Alternative zu Heroku
3. **DigitalOcean App Platform:** Kostengünstig und zuverlässig
4. **AWS/Azure:** Für Enterprise-Lösungen

## Support

Bei weiteren Problemen:

1. Prüfen Sie die Logs in `log/development.log`
2. Stellen Sie sicher, dass alle Dependencies installiert sind
3. Versuchen Sie einen Neustart des Systems
4. Erstellen Sie ein Issue im Repository mit detaillierter Fehlerbeschreibung 