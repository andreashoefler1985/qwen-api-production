#!/bin/bash

# Fixes environment variable loading and starts all services
# Designed to run in a single SSH session without timeouts

echo "🔧 AI.HOEFLER-CLOUD.COM Production Fix & Start"
echo "=============================================="

# Fix the main issue: Docker Compose looks for .env, not .env.production
echo "📋 Step 1: Copying .env.production to .env for Docker Compose..."
cp .env.production .env
echo "✅ Environment file copied"

# Stop any running services
echo "📋 Step 2: Stopping existing services..."
docker compose -f docker-compose.production.yml down 2>/dev/null || true

# Clean up
echo "📋 Step 3: Cleaning Docker cache..."
docker system prune -f

# Create directories
echo "📋 Step 4: Creating required directories..."
mkdir -p models cache logs ssl backups

# Build and start services
echo "📋 Step 5: Building and starting all services..."
docker compose -f docker-compose.production.yml up -d --build

# Wait for services
echo "📋 Step 6: Waiting 60 seconds for services to fully start..."
sleep 60

# Verify everything
echo "📋 Step 7: Verifying deployment..."
echo ""
echo "🔍 Service Status:"
docker compose -f docker-compose.production.yml ps

echo ""
echo "🔍 Environment Variables Check:"
docker exec qwen-api printenv | grep -E "(JWT_SECRET|REDIS_PASSWORD|API_DOMAIN|ENVIRONMENT)" | head -5

echo ""
echo "🔍 API Health Check:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ API responding with HTTP $HTTP_CODE"
else
    echo "⚠️ API not responding (HTTP: $HTTP_CODE)"
    echo "API Logs:"
    docker logs qwen-api --tail 10
fi

echo ""
echo "🔍 Redis Connection Test:"
REDIS_PASS=$(grep REDIS_PASSWORD .env | cut -d'=' -f2)
if docker exec redis-cache redis-cli -a "$REDIS_PASS" ping 2>/dev/null | grep -q PONG; then
    echo "✅ Redis authentication working"
else
    echo "❌ Redis authentication failed"
fi

echo ""
echo "🔍 Nginx Proxy Test:"
NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)
if [ "$NGINX_CODE" = "200" ]; then
    echo "✅ Nginx proxy working (HTTP $NGINX_CODE)"
else
    echo "⚠️ Nginx proxy issue (HTTP: $NGINX_CODE)"
fi

echo ""
echo "📊 Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "🎯 DEPLOYMENT STATUS SUMMARY:"
echo "================================"
RUNNING_SERVICES=$(docker compose -f docker-compose.production.yml ps --quiet | wc -l)
echo "Services running: $RUNNING_SERVICES/6"

if [ "$RUNNING_SERVICES" -ge "5" ]; then
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo ""
    echo "🔗 Access Information:"
    echo "   HTTP: http://136.243.130.253"
    echo "   Domain: ai.hoefler-cloud.com (configure DNS)"
    echo ""
    echo "🔑 API Keys:"
    echo "   Admin: ak_admin_nhghFm8FHSHa3PUMCS60vrJnJLhr0M-GTZAG8td8b_Y"
    echo "   API: ak_api_AVLX3VL9IB73YSVqmCVlJ8XpGXfYJZjWG3bXM6_4Z0s"
    echo "   Read-Only: ak_ro_5BHVXG2MxweMd-ZZMguEDkAc78plTwUzmNVHvJEWEdg"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Configure DNS: ai.hoefler-cloud.com → 136.243.130.253"
    echo "   2. Setup SSL: ./ssl_setup.sh"
    echo "   3. Test API with keys above"
else
    echo "❌ DEPLOYMENT INCOMPLETE - Check logs"
    echo "Run: docker compose -f docker-compose.production.yml logs"
fi

echo ""
echo "🎉 Script completed - no SSH timeouts!"
