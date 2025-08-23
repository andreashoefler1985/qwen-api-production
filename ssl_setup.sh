#!/bin/bash
# ssl_setup.sh für ai.hoefler-cloud.com

set -e

# Domain und Email konfigurieren
DOMAIN="ai.hoefler-cloud.com"
EMAIL="admin@hoefler-cloud.com"  # Anpassen falls nötig
PROJECT_DIR="$(pwd)"

echo "🔐 SSL-Setup für $DOMAIN wird gestartet..."

# Certbot installieren falls nicht vorhanden
if ! command -v certbot &> /dev/null; then
    echo "📦 Installiere Certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# SSL-Verzeichnis erstellen
mkdir -p $PROJECT_DIR/ssl
sudo mkdir -p /var/www/html

# Temporäre Nginx-Konfiguration für Zertifikat-Challenge
sudo tee /etc/nginx/sites-available/temp-ssl << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 200 'SSL Setup in Progress';
        add_header Content-Type text/plain;
    }
}
EOF

# Nginx-Site aktivieren
sudo ln -sf /etc/nginx/sites-available/temp-ssl /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# SSL-Zertifikat erstellen
echo "🚀 Erstelle SSL-Zertifikat für $DOMAIN..."
sudo certbot certonly --webroot \
    -w /var/www/html \
    -d $DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --non-interactive

# Zertifikate nach Projekt kopieren
echo "📋 Kopiere Zertifikate..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $PROJECT_DIR/ssl/cert.pem
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $PROJECT_DIR/ssl/key.pem
sudo chown $USER:$USER $PROJECT_DIR/ssl/*

# DH Parameters für zusätzliche Sicherheit
echo "🔒 Generiere DH Parameters..."
openssl dhparam -out $PROJECT_DIR/ssl/dhparam.pem 2048

# Auto-Renewal Setup
echo "⚙️ Richte automatische Erneuerung ein..."
sudo crontab -l > /tmp/cron_backup 2>/dev/null || true
echo "0 2 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'" | sudo crontab -

echo "✅ SSL-Setup für $DOMAIN abgeschlossen!"
echo "📁 Zertifikate sind in: $PROJECT_DIR/ssl/"
