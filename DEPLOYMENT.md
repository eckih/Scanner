# Produktions-Deployment Leitfaden

Dieser Leitfaden erklärt, wie Sie Ihre Ruby on Rails Kryptowährungs-Scanner Anwendung in der Produktion mit GitHub CI/CD und Docker bereitstellen.

## Voraussetzungen

### Server-Anforderungen
- Ubuntu 20.04+ oder ähnliche Linux-Distribution
- Docker und Docker Compose installiert
- Git installiert
- Mindestens 2GB RAM und 20GB Festplattenspeicher
- Offene Ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3000 (Anwendung)

### GitHub Repository Setup
- GitHub Repository mit Ihrem Code
- GitHub Actions aktiviert
- GitHub Container Registry Zugang

## 1. Server-Einrichtung

### Docker und Docker Compose installieren

```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose installieren
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Installation überprüfen
docker --version
docker-compose --version
```

### Anwendungsverzeichnis erstellen

```bash
sudo mkdir -p /opt/cryptocurrency-scanner
sudo chown $USER:$USER /opt/cryptocurrency-scanner
cd /opt/cryptocurrency-scanner
```

## 2. GitHub Secrets Konfiguration

Gehen Sie zu Ihrem GitHub Repository → Settings → Secrets and variables → Actions und fügen Sie diese Secrets hinzu:

### Erforderliche Secrets
- `HOST`: Ihre Server-IP-Adresse oder Domain
- `USERNAME`: SSH-Benutzername für Ihren Server
- `SSH_PRIVATE_KEY`: Privater SSH-Schlüssel für Server-Zugang
- `SECRET_KEY_BASE`: Rails Secret Key (generieren mit `rails secret`)

### Optionale Secrets
- `PORT`: SSH-Port (Standard: 22)
- `DEPLOY_PATH`: Deployment-Pfad (Standard: /opt/cryptocurrency-scanner)
- `SLACK_WEBHOOK`: Slack Webhook URL für Deployment-Benachrichtigungen

### SSH-Schlüsselpaar generieren

Auf Ihrem lokalen Rechner:
```bash
ssh-keygen -t rsa -b 4096 -C "deployment@ihre-domain.com"
```

Fügen Sie den öffentlichen Schlüssel zu den `~/.ssh/authorized_keys` Ihres Servers hinzu und den privaten Schlüssel zu den GitHub Secrets.

### Rails Secret Key generieren

```bash
# In Ihrem Rails-Anwendungsverzeichnis
bundle exec rails secret
```

Kopieren Sie die Ausgabe und fügen Sie sie als `SECRET_KEY_BASE` in die GitHub Secrets ein.

## 3. Umgebungskonfiguration

### Produktions-Umgebungsdatei erstellen

Kopieren Sie `env.production.example` zu `.env.production` auf Ihrem Server:

```bash
cd /opt/cryptocurrency-scanner
cp env.production.example .env.production
```

Bearbeiten Sie `.env.production` mit Ihren tatsächlichen Werten:

```bash
nano .env.production
```

### Erforderliche Umgebungsvariablen

```env
# Rails Konfiguration
RAILS_ENV=production
SECRET_KEY_BASE=ihr_tatsächlicher_secret_key_hier
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true

# Datenbank-Konfiguration
DATABASE_URL=sqlite3:db/production.sqlite3

# Redis-Konfiguration
REDIS_URL=redis://redis:6379/0

# Puma-Konfiguration
PORT=3000
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Binance API (optional - für Live-Daten)
BINANCE_API_KEY=ihr_binance_api_key
BINANCE_API_SECRET=ihr_binance_api_secret
```

## 4. Manuelles Deployment (Alternative zu CI/CD)

Wenn Sie manuelles Deployment bevorzugen, verwenden Sie das bereitgestellte Deployment-Script:

```bash
# Repository klonen
git clone https://github.com/yourusername/cryptocurrency-scanner.git /opt/cryptocurrency-scanner
cd /opt/cryptocurrency-scanner

# Deployment-Script ausführbar machen
chmod +x deploy.sh

# Deployment ausführen
./deploy.sh deploy
```

### Deployment-Script Befehle

```bash
./deploy.sh deploy    # Vollständiges Deployment
./deploy.sh update    # Code aktualisieren und neu starten
./deploy.sh logs      # Anwendungs-Logs anzeigen
./deploy.sh stop      # Anwendung stoppen
./deploy.sh start     # Anwendung starten
./deploy.sh restart   # Anwendung neu starten
./deploy.sh status    # Anwendungsstatus anzeigen
```

## 5. GitHub Actions CI/CD Setup

Der GitHub Actions Workflow (`.github/workflows/deploy.yml`) führt automatisch aus:

1. **Testet** die Anwendung
2. **Erstellt** Docker-Image
3. **Pusht** zur GitHub Container Registry
4. **Deployed** auf Ihren Server via SSH

### Workflow-Trigger
- Push zum `main` oder `master` Branch
- Pull Requests (nur Tests)

### Workflow-Schritte
1. **Test Job**: Führt Tests und Sicherheitsaudits aus
2. **Build Job**: Erstellt und pusht Docker-Image
3. **Deploy Job**: Deployed auf Produktionsserver

## 6. Produktions-Konfiguration

### Docker Compose Services

Das Produktions-Setup umfasst:

- **Web**: Haupt-Rails-Anwendung
- **Redis**: Caching und Hintergrund-Jobs
- **Sidekiq**: Hintergrund-Job-Verarbeitung

### Sicherheitsfeatures

- Non-root Benutzer im Docker-Container
- Health Checks für Überwachung
- Log-Rotation
- Ressourcen-Limits
- Sichere Session-Konfiguration

### Performance-Optimierungen

- Multi-Stage Docker Builds
- Asset-Vorkompilierung
- Puma Worker-Prozesse
- Redis-Caching
- Datenbank-Connection-Pooling

## 7. Überwachung und Wartung

### Health Checks

Die Anwendung bietet einen Health Check Endpunkt:
```
GET /health
```

### Log-Überwachung

```bash
# Anwendungs-Logs anzeigen
./deploy.sh logs

# Spezifische Service-Logs anzeigen
docker-compose -f docker-compose.production.yml logs web
docker-compose -f docker-compose.production.yml logs sidekiq
docker-compose -f docker-compose.production.yml logs redis
```

### Datenbank-Wartung

```bash
# Rails Console zugreifen
docker-compose -f docker-compose.production.yml exec web bundle exec rails console

# Datenbank-Migrationen ausführen
docker-compose -f docker-compose.production.yml exec web bundle exec rails db:migrate

# Datenbank sichern
cp db/production.sqlite3 db/backup_$(date +%Y%m%d_%H%M%S).sqlite3
```

### System-Überwachung

```bash
# Container-Status prüfen
docker-compose -f docker-compose.production.yml ps

# Ressourcenverbrauch prüfen
docker stats

# Festplattenverbrauch prüfen
df -h
du -sh /opt/cryptocurrency-scanner
```

## 8. SSL/HTTPS Setup (Empfohlen)

### Nginx Reverse Proxy verwenden

Nginx installieren:
```bash
sudo apt install nginx
```

Nginx-Konfiguration erstellen:
```nginx
server {
    listen 80;
    server_name ihre-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Let's Encrypt SSL verwenden

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d ihre-domain.com
```

## 9. Backup-Strategie

### Automatisiertes Backup-Script

Erstellen Sie `/opt/cryptocurrency-scanner/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/cryptocurrency-scanner"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Datenbank sichern
cp /opt/cryptocurrency-scanner/db/production.sqlite3 $BACKUP_DIR/db_$DATE.sqlite3

# Logs sichern
tar -czf $BACKUP_DIR/logs_$DATE.tar.gz /opt/cryptocurrency-scanner/log/

# Nur die letzten 7 Tage der Backups behalten
find $BACKUP_DIR -name "*.sqlite3" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

Zu Crontab hinzufügen:
```bash
crontab -e
# Hinzufügen: 0 2 * * * /opt/cryptocurrency-scanner/backup.sh
```

## 10. Fehlerbehebung

### Häufige Probleme

1. **Anwendung startet nicht**
   ```bash
   ./deploy.sh logs
   docker-compose -f docker-compose.production.yml ps
   ```

2. **Datenbank-Verbindungsfehler**
   ```bash
   # Datenbank-Dateiberechtigungen prüfen
   ls -la db/
   # Datenbank neu erstellen
   docker-compose -f docker-compose.production.yml exec web bundle exec rails db:create
   ```

3. **Speicherprobleme**
   ```bash
   # Speicherverbrauch prüfen
   free -h
   # Anwendung neu starten
   ./deploy.sh restart
   ```

4. **Port-Konflikte**
   ```bash
   # Prüfen was Port 3000 verwendet
   sudo netstat -tulpn | grep :3000
   ```

### Log-Standorte

- Anwendungs-Logs: `/opt/cryptocurrency-scanner/log/`
- Docker-Logs: `docker-compose logs`
- System-Logs: `/var/log/`

### Performance-Tuning

1. **Worker-Prozesse erhöhen** (wenn Sie mehr CPU-Kerne haben):
   ```env
   WEB_CONCURRENCY=4
   RAILS_MAX_THREADS=10
   ```

2. **Speicher-Überwachung hinzufügen**:
   ```env
   PUMA_WORKER_MAX_MEMORY=512
   ```

3. **Datenbank optimieren**:
   ```bash
   # In Rails Console
   ActiveRecord::Base.connection.execute("VACUUM;")
   ActiveRecord::Base.connection.execute("ANALYZE;")
   ```

## 11. Skalierungs-Überlegungen

### Horizontale Skalierung
- Load Balancer verwenden (Nginx, HAProxy)
- Mehrere Anwendungsinstanzen
- Geteilte Redis-Instanz
- Externe Datenbank (PostgreSQL)

### Vertikale Skalierung
- Server-Ressourcen erhöhen
- Puma-Konfiguration optimieren
- Überwachung hinzufügen (New Relic, DataDog)

## Support

Für Probleme und Fragen:
1. Prüfen Sie zuerst die Logs
2. Lesen Sie diese Dokumentation
3. Prüfen Sie GitHub Issues
4. Erstellen Sie ein neues Issue mit Logs und Fehlerdetails

---

**Sicherheitshinweis**: Halten Sie Ihren Server immer aktuell, verwenden Sie starke Passwörter, aktivieren Sie die Firewall und sichern Sie Ihre Daten regelmäßig. 