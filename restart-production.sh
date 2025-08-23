#!/bin/bash

# Produktions-Services mit korrekten Umgebungsvariablen starten
# Script für ai.hoefler-cloud.com Server: 136.243.130.253

set -e

echo "🔄 Starting Production Services mit .env.production Variablen..."

# Prüfe ob .env.production existiert
if [ ! -f ".env.production" ]; then
    echo "❌ Error: .env.production nicht gefunden!"
    echo "Bitte zuerst generate_secure_tokens.py ausführen"
    exit 1
fi

# Stoppe alle laufenden Services (falls vorhanden)
echo "⏹️ Stopping existing services..."
sudo docker compose -f docker-compose.production.yml down 2>/dev/null || true

# Bereinige alte Container und Images
echo "🧹 Cleaning up..."
sudo docker system prune -f

# Erstelle benötigte Verzeichnisse
echo "📁 Creating required directories..."
sudo mkdir -p models cache logs ssl backups
sudo mkdir -p fail2ban/jail.d fail2ban/filter.d fail2ban/action.d

# Prüfe Docker Compose Installation
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose nicht installiert!"
    exit 1
fi

# Prüfe NVIDIA Docker Runtime
if ! sudo docker run --rm --gpus all nvidia/cuda:12.2-base-ubuntu22.04 nvidia-smi &>/dev/null; then
    echo "⚠️ Warning: NVIDIA Docker Runtime nicht verfügbar"
    echo "GPU-Unterstützung möglicherweise nicht funktionsfähig"
fi

# Build und starte Services
echo "🚀 Building and starting services..."
sudo docker compose -f docker-compose.production.yml up -d --build

# Warte bis Services laufen
echo "⏳ Waiting for services to start..."
sleep 45

# Verifiziere Status aller Services
echo ""
echo "✅ Checking service status..."
sudo docker compose -f docker-compose.production.yml ps

echo ""
echo "🔍 Verifying environment variables in qwen-api..."
if sudo docker exec qwen-api printenv | grep -E "(JWT_SECRET|REDIS_PASSWORD|API_DOMAIN)" >/dev/null 2>&1; then
    echo "✅ Environment variables loaded successfully"
    sudo docker exec qwen-api printenv | grep -E "(API_DOMAIN|LOG_LEVEL|ENVIRONMENT)" | head -3
else
    echo "❌ Environment variables not loaded properly"
    echo "Checking container logs:"
    sudo docker logs qwen-api --tail 20
fi

echo ""
echo "🔍 Testing Redis connection..."
REDIS_PASS=$(grep REDIS_PASSWORD .env.production | cut -d'=' -f2)
if sudo docker exec redis-cache redis-cli -a "$REDIS_PASS" ping 2>/dev/null | grep -q PONG; then
    echo "✅ Redis authentication working"
else
    echo "❌ Redis authentication failed"
    echo "Redis logs:"
    sudo docker logs redis-cache --tail 10
fi

echo ""
echo "🌐 Testing API endpoint..."
sleep 15

# Test lokalen Health-Check
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null | grep -q 200; then
    echo "✅ API Health check successful (HTTP)"
else
    echo "⚠️ API not responding on port 8000"
    echo "API logs:"
    sudo docker logs qwen-api --tail 20
fi

# Test Nginx
if curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null | grep -q 200; then
    echo "✅ Nginx proxy working"
else
    echo "⚠️ Nginx proxy not working yet"
    echo "Nginx logs:"
    sudo docker logs nginx-proxy --tail 10
fi

echo ""
echo "📊 Container resource usage:"
sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo ""
echo "📋 Service Status Summary:"
echo "================================"
sudo docker compose -f docker-compose.production.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔗 Network Information:"
echo "================================"
echo "Server IP: 136.243.130.253"
echo "Domain: ai.hoefler-cloud.com (DNS konfiguration erforderlich)"
echo "HTTP: http://136.243.130.253"
echo "HTTPS: https://ai.hoefler-cloud.com (nach SSL-Setup)"

echo ""
echo "🔑 API Keys (für Tests):"
echo "================================"
echo "Admin: ak_admin_nhghFm8FHSHa3PUMCS60vrJnJLhr0M-GTZAG8td8b_Y"
echo "API: ak_api_AVLX3VL9IB73YSVqmCVlJ8XpGXfYJZjWG3bXM6_4Z0s"
echo "Read-Only: ak_ro_5BHVXG2MxweMd-ZZMguEDkAc78plTwUzmNVHvJEWEdg"

echo ""
echo "📝 Useful Commands:"
echo "================================"
echo "Logs anzeigen:     sudo docker compose -f docker-compose.production.yml logs -f"
echo "Services neustarten: sudo docker compose -f docker-compose.production.yml restart"
echo "Status prüfen:     sudo docker compose -f docker-compose.production.yml ps"
echo "GPU Status:        sudo docker exec qwen-api nvidia-smi"

echo ""
if [ $(sudo docker compose -f docker-compose.production.yml ps --quiet | wc -l) -eq 6 ]; then
    echo "✅ All services started successfully!"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. DNS für ai.hoefler-cloud.com konfigurieren"
    echo "   2. SSL-Zertifikat einrichten: sudo ./ssl_setup.sh"
    echo "   3. API testen mit den generierten Keys"
    echo "   4. Firewall konfigurieren falls nötig"
else
    echo "⚠️  Some services may not be running properly"
    echo "   Check logs: sudo docker compose -f docker-compose.production.yml logs"
fi

echo ""
echo "🎯 Production Deployment Complete!"
