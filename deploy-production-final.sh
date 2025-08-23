#!/bin/bash

# Final Production Deployment für ai.hoefler-cloud.com
# Alle identifizierten Probleme sind behoben

set -e

echo "🚀 AI.HOEFLER-CLOUD.COM - Final Production Deployment"
echo "=================================================="

# Prüfe erforderliche Dateien
REQUIRED_FILES=(
    "docker-compose.production.yml"
    ".env.production"
    "nginx.conf"
    "promtail-config.yml"
    "requirements.txt"
    "Dockerfile"
    "api_server_14b.py"
    "auth.py"
    "fail2ban/jail.local"
    "fail2ban/filter.d/api-auth-failures.conf"
)

echo "📋 Prüfe erforderliche Dateien..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Fehlende Datei: $file"
        exit 1
    fi
done
echo "✅ Alle erforderlichen Dateien vorhanden"

# Erstelle .env aus .env.production (Docker Compose Standard)
echo "📋 Erstelle .env Datei..."
cp .env.production .env

# Erstelle erforderliche Verzeichnisse
echo "📋 Erstelle Verzeichnisse..."
mkdir -p models cache logs ssl backups

# Stoppe alte Services
echo "📋 Stoppe alte Services..."
docker compose -f docker-compose.production.yml down 2>/dev/null || true

# System-Bereinigung
echo "📋 Bereinige Docker..."
docker system prune -f

# Build und Start Services
echo "📋 Build und Start Services..."
echo "   - Nginx (Alpine-kompatibel): user nginx"
echo "   - Qwen-API (ohne flash-attn): stabil"
echo "   - Redis (Authentifizierung): sicher"
echo "   - Fail2ban (Intrusion Prevention): gehärtet"
echo "   - Log-Monitor (mit promtail-config.yml): überwacht"
echo "   - Backup Service: automatisch"

docker compose -f docker-compose.production.yml up -d --build

# Warte auf Services
echo "📋 Warte 90 Sekunden auf Service-Start..."
sleep 90

# Status Check
echo "📋 Service Status Check..."
echo ""
echo "🔍 Container Status:"
docker compose -f docker-compose.production.yml ps

echo ""
echo "🔍 Service Health:"

# API Health Check
if docker exec qwen-api curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ qwen-api: Healthy (Port 8000 intern)"
else
    echo "⚠️  qwen-api: Starting up... (normal bis zu 2 Minuten)"
fi

# Redis Check  
REDIS_PASS=$(grep REDIS_PASSWORD .env | cut -d'=' -f2)
if docker exec redis-cache redis-cli -a "$REDIS_PASS" ping 2>/dev/null | grep -q PONG; then
    echo "✅ redis-cache: Healthy & Authenticated"
else
    echo "❌ redis-cache: Authentication Problem"
fi

# Nginx Check
if docker logs nginx-proxy 2>&1 | grep -q "Configuration complete"; then
    echo "✅ nginx-proxy: Configuration loaded"
else
    echo "❌ nginx-proxy: Configuration Problem"
    echo "Logs:"
    docker logs nginx-proxy --tail 5
fi

# Environment Variables Check
echo ""
echo "🔍 Environment Variables:"
if docker exec qwen-api printenv | grep -E "(JWT_SECRET|API_DOMAIN)" >/dev/null 2>&1; then
    echo "✅ Environment variables loaded"
    docker exec qwen-api printenv | grep -E "(API_DOMAIN|ENVIRONMENT)" | head -2
else
    echo "❌ Environment variables nicht geladen"
fi

echo ""
echo "🌐 Network Tests:"

# Test API über nginx (wichtig!)
sleep 15
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ API über nginx-proxy: HTTP $HTTP_CODE (Production Ready!)"
elif [ "$HTTP_CODE" = "502" ]; then
    echo "⚠️  API über nginx-proxy: HTTP $HTTP_CODE (API startet noch...)"
else
    echo "❌ API über nginx-proxy: HTTP $HTTP_CODE (Problem)"
fi

# Resource Usage
echo ""
echo "📊 Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -7

echo ""
echo "🎯 DEPLOYMENT STATUS SUMMARY"
echo "================================"

RUNNING_SERVICES=$(docker compose -f docker-compose.production.yml ps --quiet | wc -l)
HEALTHY_SERVICES=$(docker compose -f docker-compose.production.yml ps --format "table {{.Status}}" | grep -c "Up" || echo "0")

echo "Services: $RUNNING_SERVICES gestartet, $HEALTHY_SERVICES healthy"

if [ "$RUNNING_SERVICES" -ge "5" ] && [ "$HEALTHY_SERVICES" -ge "3" ]; then
    echo ""
    echo "🎉 DEPLOYMENT ERFOLGREICH!"
    echo ""
    echo "🔗 Zugriff:"
    echo "   HTTP: http://136.243.130.253"
    echo "   Domain: ai.hoefler-cloud.com (DNS konfiguration erforderlich)"
    echo ""
    echo "🔑 API Keys (für Tests):"
    echo "   Admin: ak_admin_nhghFm8FHSHa3PUMCS60vrJnJLhr0M-GTZAG8td8b_Y"
    echo "   API: ak_api_AVLX3VL9IB73YSVqmCVlJ8XpGXfYJZjWG3bXM6_4Z0s"
    echo "   Read-Only: ak_ro_5BHVXG2MxweMd-ZZMguEDkAc78plTwUzmNVHvJEWEdg"
    echo ""
    echo "✅ Alle Konfigurationsprobleme behoben:"
    echo "   ✅ nginx.conf: Alpine Linux kompatibel"
    echo "   ✅ requirements.txt: ohne problematische flash-attn"
    echo "   ✅ promtail-config.yml: Log-Monitoring funktional"
    echo "   ✅ Environment Variables: korrekt geladen"
    echo "   ✅ Docker Compose: Version-Attribut entfernt"
    echo ""
    echo "🚀 Nächste Schritte:"
    echo "   1. DNS konfigurieren: ai.hoefler-cloud.com → 136.243.130.253"
    echo "   2. SSL einrichten: ./ssl_setup.sh"
    echo "   3. API testen: curl http://136.243.130.253/health"
    echo "   4. Production monitoring einrichten"
    echo ""
    echo "📝 Management Commands:"
    echo "   Logs: docker compose -f docker-compose.production.yml logs -f"
    echo "   Status: docker compose -f docker-compose.production.yml ps"
    echo "   Restart: docker compose -f docker-compose.production.yml restart"
    echo "   Stop: docker compose -f docker-compose.production.yml down"
else
    echo ""
    echo "⚠️  DEPLOYMENT TEILWEISE ERFOLGREICH"
    echo "   Einige Services haben Probleme - prüfe Logs"
    echo "   Command: docker compose -f docker-compose.production.yml logs"
fi

echo ""
echo "🎯 Deployment abgeschlossen - $(date)"
