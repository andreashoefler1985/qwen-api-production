#!/bin/bash
# ~/qwen-api/deploy.sh

set -e

echo "🚀 Starting Qwen API Deployment..."

# Check requirements
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
command -v nvidia-smi >/dev/null 2>&1 || { echo "NVIDIA GPU driver is required but not found. Aborting." >&2; exit 1; }

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "❌ .env file not found. Please create it first."
    exit 1
fi

# Check SSL certificates
if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
    echo "❌ SSL certificates not found. Please run ssl_setup.sh first."
    exit 1
fi

# Create necessary directories
mkdir -p {models,cache,logs}
chmod 755 {models,cache,logs}

# Update nginx config with actual domain
sed -i "s/your-domain.com/$API_DOMAIN/g" nginx.conf

echo "📦 Building Docker images..."
docker-compose build

echo "🔄 Starting services..."
docker-compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 30

# Health check
echo "🏥 Performing health checks..."
for i in {1..30}; do
    if curl -f https://$API_DOMAIN/health >/dev/null 2>&1; then
        echo "✅ API is healthy!"
        break
    fi
    echo "⏳ Waiting for API... ($i/30)"
    sleep 10
done

# Create admin API key
echo "🔑 Creating admin API key..."
ADMIN_KEY=$(docker-compose exec -T qwen-api python3 -c "
import asyncio
from auth import api_key_manager
async def create_admin():
    key = await api_key_manager.create_api_key('admin', ['admin', 'generate'])
    print(key)
asyncio.run(create_admin())
")

echo ""
echo "🎉 Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 API Endpoint: https://$API_DOMAIN/v1/generate"
echo "🏥 Health Check: https://$API_DOMAIN/health"
echo "🔑 Admin API Key: $ADMIN_KEY"
echo ""
echo "📖 Usage Examples:"
echo "   # Generate text"
echo "   curl -X POST https://$API_DOMAIN/v1/generate \\"
echo "     -H 'Authorization: Bearer YOUR_API_KEY' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"prompt\": \"Write a Python function to calculate fibonacci numbers\"}'"
echo ""
echo "   # OpenAI-compatible endpoint"
echo "   curl -X POST https://$API_DOMAIN/v1/chat/completions \\"
echo "     -H 'Authorization: Bearer YOUR_API_KEY' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"