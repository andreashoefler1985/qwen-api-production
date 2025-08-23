#!/bin/bash
# final_setup.sh - Run this after downloading all files

set -e

echo "🚀 Final Qwen API Setup"
echo "======================"

# Make scripts executable
chmod +x *.sh

# Check all files are present
REQUIRED_FILES=(
    "Dockerfile"
    "requirements.txt"
    "docker-compose.yml"
    "nginx.conf"
    "api_server.py"
    "auth.py"
    ".env"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        exit 1
    fi
done

echo "✅ All required files present"

# Validate environment
if [ ! -f .env ]; then
    echo "❌ Please create .env file first"
    exit 1
fi

source .env

if [ -z "$API_DOMAIN" ] || [ -z "$JWT_SECRET" ] || [ -z "$REDIS_PASSWORD" ]; then
    echo "❌ Please check .env configuration"
    exit 1
fi

echo "✅ Environment configuration valid"

# Check SSL certificates
if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
    echo "❌ SSL certificates not found. Run ssl setup first."
    exit 1
fi

echo "✅ SSL certificates found"

# Update nginx config with domain
sed -i "s/your-domain.com/$API_DOMAIN/g" nginx.conf

# Deploy
echo "🚀 Starting deployment..."
./deploy.sh

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Your Qwen 2.5 Coder API is now running at: https://$API_DOMAIN"
echo ""
echo "Available commands:"
echo "  ./manage.sh start          - Start services"
echo "  ./manage.sh stop           - Stop services"
echo "  ./manage.sh logs           - View logs"
echo "  ./manage.sh create-key     - Create API key"
echo "  ./manage.sh monitor        - Real-time monitoring"
echo "  python3 test_api.py        - Test API functionality"
echo ""
echo "Happy coding! 🤖"