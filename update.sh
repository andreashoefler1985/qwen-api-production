#!/bin/bash
# ~/qwen-api/update.sh

set -e

echo "🔄 Starting Qwen API Update Process..."

# Backup before update
echo "💾 Creating pre-update backup..."
./backup.sh

# Pull latest changes (if using git)
if [ -d .git ]; then
    echo "📥 Pulling latest changes..."
    git pull origin main
fi

# Check for environment changes
if [ -f .env.example ] && ! cmp -s .env.example .env; then
    echo "⚠️  Environment file has changed. Please review .env.example"
    echo "Current .env:"
    cat .env
    echo ""
    echo "Example .env:"
    cat .env.example
    echo ""
    read -p "Continue with update? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Update Docker images
echo "🐳 Updating Docker images..."
docker-compose pull

# Rebuild services
echo "🔨 Rebuilding services..."
docker-compose build --no-cache

# Check SSL certificate expiration
echo "🔐 Checking SSL certificate..."
CERT_EXPIRY=$(openssl x509 -enddate -noout -in ssl/cert.pem | cut -d= -f2)
EXPIRY_DATE=$(date -d "$CERT_EXPIRY" +%s)
CURRENT_DATE=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_DATE - $CURRENT_DATE) / 86400 ))

if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
    echo "⚠️  SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
    echo "Renewing certificate..."
    sudo certbot renew --quiet
    sudo cp /etc/letsencrypt/live/$(cat .env | grep API_DOMAIN | cut -d= -f2)/fullchain.pem ssl/cert.pem
    sudo cp /etc/letsencrypt/live/$(cat .env | grep API_DOMAIN | cut -d= -f2)/privkey.pem ssl/key.pem
    sudo chown $USER:$USER ssl/*
fi

# Restart services with zero downtime
echo "🔄 Performing rolling restart..."
docker-compose up -d --no-deps --build nginx
sleep 10
docker-compose up -d --no-deps --build qwen-api
sleep 10
docker-compose up -d --no-deps redis

# Health check
echo "🏥 Performing post-update health check..."
sleep 30

if python3 test_api.py --quick; then
    echo "✅ Update completed successfully!"
else
    echo "❌ Update failed health check. Rolling back..."
    # Implement rollback logic here
    docker-compose down
    # Restore from backup if needed
    docker-compose up -d
    exit 1
fi

echo ""
echo "🎉 Update Process Complete!"
echo "=========================="
echo "Next steps:"
echo "1. Monitor logs: ./manage.sh logs"
echo "2. Check metrics: curl https://your-domain.com/stats"
echo "3. Test API: python3 test_api.py"