#!/bin/bash
# Automatisches Backup-System für ai.hoefler-cloud.com

set -e

# Konfiguration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
S3_BUCKET=${BACKUP_S3_BUCKET:-}
LOG_FILE="./logs/backup_${DATE}.log"

# Logging-Funktion
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Backup-Verzeichnis erstellen
mkdir -p "$BACKUP_DIR"
mkdir -p "./logs"

log "🚀 Starte Backup-Prozess..."

# 1. Redis-Daten sichern
log "📊 Sichere Redis-Daten..."
if docker ps --format '{{.Names}}' | grep -q "redis-cache"; then
    docker exec redis-cache redis-cli --rdb /tmp/redis_backup.rdb
    docker cp redis-cache:/tmp/redis_backup.rdb "$BACKUP_DIR/redis_${DATE}.rdb"
    log "✅ Redis-Backup erstellt"
else
    log "⚠️ Redis-Container nicht gefunden"
fi

# 2. SSL-Zertifikate sichern
log "🔐 Sichere SSL-Zertifikate..."
if [ -d "./ssl" ]; then
    tar -czf "$BACKUP_DIR/ssl_${DATE}.tar.gz" ./ssl/
    log "✅ SSL-Backup erstellt"
else
    log "⚠️ SSL-Verzeichnis nicht gefunden"
fi

# 3. Konfigurationsdateien sichern
log "⚙️ Sichere Konfigurationsdateien..."
tar -czf "$BACKUP_DIR/config_${DATE}.tar.gz" \
    docker-compose.production.yml \
    nginx.conf \
    .env.production \
    fail2ban/ \
    --exclude='*.log' \
    --exclude='*.tmp' 2>/dev/null || true
log "✅ Konfigurations-Backup erstellt"

# 4. Anwendungslogs sichern
log "📝 Sichere Anwendungslogs..."
if [ -d "./logs" ]; then
    tar -czf "$BACKUP_DIR/logs_${DATE}.tar.gz" ./logs/ --exclude="backup_*.log" 2>/dev/null || true
    log "✅ Log-Backup erstellt"
fi

# 5. Modelle sichern (optional, da sehr groß)
if [ "${BACKUP_MODELS:-false}" = "true" ] && [ -d "./models" ]; then
    log "🤖 Sichere ML-Modelle..."
    tar -czf "$BACKUP_DIR/models_${DATE}.tar.gz" ./models/
    log "✅ Modell-Backup erstellt"
fi

# 6. Vollständiges System-Backup erstellen
log "📦 Erstelle vollständiges System-Backup..."
tar -czf "$BACKUP_DIR/full_system_${DATE}.tar.gz" \
    --exclude="./backups" \
    --exclude="./logs/backup_*.log" \
    --exclude="./models" \
    --exclude=".git" \
    --exclude="__pycache__" \
    --exclude="*.pyc" \
    --exclude="node_modules" \
    ./ 2>/dev/null || true

# 7. Backup-Größe berechnen
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "📊 Backup-Größe: $BACKUP_SIZE"

# 8. S3-Upload (optional)
if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
    log "☁️ Lade Backups zu S3 hoch..."
    aws s3 sync "$BACKUP_DIR" "s3://$S3_BUCKET/ai-hoefler-cloud/$(date +%Y/%m)/" \
        --exclude "*" --include "*${DATE}*" || log "❌ S3-Upload fehlgeschlagen"
    log "✅ S3-Upload abgeschlossen"
fi

# 9. Alte Backups löschen
log "🧹 Lösche alte Backups (älter als $RETENTION_DAYS Tage)..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# 10. Backup-Bericht erstellen
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*${DATE}* 2>/dev/null | wc -l)
log "✅ Backup abgeschlossen!"
log "📊 $BACKUP_COUNT Backup-Dateien erstellt"
log "📁 Backup-Verzeichnis: $BACKUP_DIR"

# 11. Health-Check für kritische Services
log "🔍 Service Health-Check..."
if curl -s -f https://ai.hoefler-cloud.com/health > /dev/null 2>&1; then
    log "✅ API ist erreichbar"
else
    log "❌ API nicht erreichbar - möglicherweise Problem!"
fi

if docker ps --filter "name=nginx-proxy" --filter "status=running" -q | wc -l | grep -q "1"; then
    log "✅ Nginx läuft"
else
    log "❌ Nginx-Problem erkannt!"
fi

log "🎉 Backup-Prozess erfolgreich abgeschlossen!"

# 12. Cleanup temporärer Dateien
rm -f /tmp/redis_backup.rdb 2>/dev/null || true

exit 0
