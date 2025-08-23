#!/bin/bash
# Produktions-Deployment für ai.hoefler-cloud.com
# Vollständig gehärtete Server-Konfiguration

set -e

# Farbcodes für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Überprüfung der Voraussetzungen
check_prerequisites() {
    log "🔍 Überprüfe Voraussetzungen..."
    
    # Docker überprüfen
    if ! command -v docker &> /dev/null; then
        error "Docker ist nicht installiert!"
        exit 1
    fi
    
    # Docker Compose überprüfen
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose ist nicht installiert!"
        exit 1
    fi
    
    # NVIDIA Docker überprüfen
    if ! docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi &> /dev/null; then
        error "NVIDIA Docker Runtime ist nicht korrekt konfiguriert!"
        exit 1
    fi
    
    # Environment-Datei überprüfen
    if [ ! -f ".env.production" ]; then
        error ".env.production Datei nicht gefunden!"
        error "Bitte kopiere .env.production und konfiguriere die Variablen!"
        exit 1
    fi
    
    log "✅ Alle Voraussetzungen erfüllt"
}

# Environment-Variablen validieren
validate_env() {
    log "🔧 Validiere Environment-Konfiguration..."
    
    source .env.production
    
    # Kritische Variablen prüfen
    if [ "$JWT_SECRET" = "your-super-secure-jwt-secret-key-here-change-this" ]; then
        error "JWT_SECRET muss geändert werden!"
        exit 1
    fi
    
    if [ "$REDIS_PASSWORD" = "your-secure-redis-password-change-this" ]; then
        error "REDIS_PASSWORD muss geändert werden!"
        exit 1
    fi
    
    # Sichere Passwörter generieren falls nötig
    if [ ${#JWT_SECRET} -lt 32 ]; then
        warn "JWT_SECRET ist zu kurz. Generiere neues..."
        JWT_NEW=$(openssl rand -hex 32)
        sed -i.bak "s/JWT_SECRET=.*/JWT_SECRET=$JWT_NEW/" .env.production
    fi
    
    if [ ${#REDIS_PASSWORD} -lt 16 ]; then
        warn "REDIS_PASSWORD ist zu kurz. Generiere neues..."
        REDIS_NEW=$(openssl rand -hex 16)
        sed -i.bak "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_NEW/" .env.production
    fi
    
    log "✅ Environment-Konfiguration validiert"
}

# Firewall konfigurieren
setup_firewall() {
    log "🔥 Konfiguriere Firewall..."
    
    # UFW installieren falls nicht vorhanden
    if ! command -v ufw &> /dev/null; then
        sudo apt update
        sudo apt install -y ufw
    fi
    
    # Firewall-Regeln
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # SSH erlauben (vorsichtig!)
    sudo ufw allow ssh
    
    # HTTP/HTTPS erlauben
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Firewall aktivieren
    sudo ufw --force enable
    
    log "✅ Firewall konfiguriert"
}

# SSL-Zertifikat einrichten
setup_ssl() {
    log "🔐 Richte SSL-Zertifikat ein..."
    
    # SSL-Setup ausführen
    chmod +x ssl_setup.sh
    ./ssl_setup.sh
    
    # Zertifikat-Pfade validieren
    if [ ! -f "./ssl/cert.pem" ] || [ ! -f "./ssl/key.pem" ]; then
        error "SSL-Zertifikate nicht gefunden!"
        exit 1
    fi
    
    log "✅ SSL-Zertifikat eingerichtet"
}

# System-Härtung
harden_system() {
    log "🛡️ Härte System..."
    
    # SSH-Härtung
    if [ -f "ssh_hardening.sh" ]; then
        chmod +x ssh_hardening.sh
        ./ssh_hardening.sh
    fi
    
    # Fail2ban einrichten
    sudo apt install -y fail2ban
    
    log "✅ System gehärtet"
}

# Docker-Services stoppen
stop_services() {
    log "⏹️ Stoppe laufende Services..."
    
    docker-compose -f docker-compose.yml down 2>/dev/null || true
    docker-compose -f docker-compose.production.yml down 2>/dev/null || true
    
    log "✅ Services gestoppt"
}

# Production-Services starten
start_production() {
    log "🚀 Starte Produktions-Services..."
    
    # Environment-Datei laden
    export $(cat .env.production | grep -v '^#' | xargs)
    
    # Production-Compose ausführen
    docker-compose -f docker-compose.production.yml up -d
    
    log "✅ Produktions-Services gestartet"
}

# Health-Check durchführen
health_check() {
    log "🏥 Führe Health-Check durch..."
    
    # Warten bis Services bereit sind
    sleep 30
    
    # API Health-Check
    local retries=12
    local wait_time=10
    
    for i in $(seq 1 $retries); do
        if curl -s -f https://ai.hoefler-cloud.com/health > /dev/null 2>&1; then
            log "✅ API ist erreichbar"
            break
        else
            if [ $i -eq $retries ]; then
                error "API nicht erreichbar nach $((retries * wait_time)) Sekunden!"
                return 1
            fi
            info "Warte auf API... ($i/$retries)"
            sleep $wait_time
        fi
    done
    
    # Service-Status prüfen
    if ! docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
        error "Nicht alle Services laufen!"
        docker-compose -f docker-compose.production.yml logs
        return 1
    fi
    
    log "✅ Health-Check bestanden"
}

# API-Keys generieren
setup_api_keys() {
    log "🔑 Richte API-Key Management ein..."
    
    # Python-Skript für API-Key-Erstellung
    cat > generate_api_key.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import sys
import os
sys.path.append('.')
from auth import APIKeyManager

async def create_admin_key():
    manager = APIKeyManager()
    api_key = await manager.create_api_key(
        user_id="admin",
        permissions=["admin", "generate", "manage"]
    )
    print(f"Admin API-Key: {api_key}")
    print(f"Speichere diesen Key sicher!")

if __name__ == "__main__":
    asyncio.run(create_admin_key())
EOF
    
    chmod +x generate_api_key.py
    
    # Admin-Key generieren
    info "Generiere Admin API-Key..."
    python3 generate_api_key.py > api_admin_key.txt
    
    warn "⚠️  Admin API-Key wurde in api_admin_key.txt gespeichert!"
    warn "⚠️  Sichere diesen Key und lösche die Datei anschließend!"
    
    log "✅ API-Key Management eingerichtet"
}

# Backup-System einrichten
setup_backup() {
    log "💾 Richte Backup-System ein..."
    
    # Backup-Skript ausführbar machen
    chmod +x backup.sh
    
    # Cron-Job für tägliche Backups
    (crontab -l 2>/dev/null || true; echo "0 2 * * * cd $(pwd) && ./backup.sh") | crontab -
    
    # Erstes Backup erstellen
    ./backup.sh
    
    log "✅ Backup-System eingerichtet"
}

# Monitoring einrichten
setup_monitoring() {
    log "📊 Richte Monitoring ein..."
    
    # System-Monitor ausführbar machen
    chmod +x system_monitor.sh
    
    # Security-Monitor einrichten
    chmod +x security_monitor.sh
    
    log "✅ Monitoring eingerichtet"
}

# Bereinigung
cleanup() {
    log "🧹 Bereinige temporäre Dateien..."
    
    # Backup-Dateien von sed entfernen
    rm -f .env.production.bak
    
    # Docker-Images bereinigen
    docker system prune -f
    
    log "✅ Bereinigung abgeschlossen"
}

# Deployment-Zusammenfassung
deployment_summary() {
    log "📋 Deployment-Zusammenfassung:"
    echo ""
    info "🌐 Domain: https://ai.hoefler-cloud.com"
    info "🔑 Admin API-Key: Siehe api_admin_key.txt"
    info "📊 Health-Check: https://ai.hoefler-cloud.com/health"
    info "📈 Metrics: https://ai.hoefler-cloud.com/metrics (nur lokal)"
    info "📁 Backups: ./backups/"
    info "📝 Logs: ./logs/"
    echo ""
    warn "⚠️  WICHTIGE NEXT STEPS:"
    warn "   1. Admin API-Key aus api_admin_key.txt kopieren und Datei löschen"
    warn "   2. DNS für ai.hoefler-cloud.com auf diesen Server zeigen lassen"
    warn "   3. SSL-Zertifikat testen: https://www.ssllabs.com/ssltest/"
    warn "   4. API-Endpunkte testen"
    warn "   5. Monitoring-Alerts konfigurieren"
    echo ""
}

# Haupt-Deployment-Funktion
main() {
    log "🚀 Starte Produktions-Deployment für ai.hoefler-cloud.com"
    echo ""
    
    # Sicherheitsabfrage
    read -p "⚠️  Sind Sie sicher, dass Sie das Produktions-Deployment starten möchten? (ja/nein): " confirm
    if [ "$confirm" != "ja" ]; then
        error "Deployment abgebrochen"
        exit 1
    fi
    
    # Deployment-Schritte
    check_prerequisites
    validate_env
    setup_firewall
    setup_ssl
    harden_system
    stop_services
    start_production
    health_check
    setup_api_keys
    setup_backup
    setup_monitoring
    cleanup
    deployment_summary
    
    log "🎉 Produktions-Deployment erfolgreich abgeschlossen!"
}

# Fehlerbehandlung
trap 'error "Deployment fehlgeschlagen! Überprüfe die Logs."; exit 1' ERR

# Skript ausführen
main "$@"
