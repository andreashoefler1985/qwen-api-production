#!/bin/bash
# ~/qwen-api/install.sh

set -e

echo "🚀 Qwen 2.5 Coder API - Complete Installation"
echo "=============================================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please don't run as root. Run as regular user with sudo access."
    exit 1
fi

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    sudo apt update && sudo apt install -y curl
fi

if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo apt install -y git
fi

# System setup
echo "📦 Setting up system..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install basic packages
sudo apt install -y \
    curl wget git vim htop \
    build-essential software-properties-common \
    apt-transport-https ca-certificates \
    gnupg lsb-release unzip \
    fail2ban ufw

# NVIDIA setup
echo "🎮 Setting up NVIDIA drivers..."

if ! command -v nvidia-smi &> /dev/null; then
    echo "Installing NVIDIA drivers..."
    
    # Add NVIDIA repository
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt update
    
    # Install NVIDIA driver and CUDA
    sudo apt install -y nvidia-driver-535 nvidia-cuda-toolkit
    
    echo "⚠️  NVIDIA driver installed. System reboot required!"
    echo "Run 'sudo reboot' and then re-run this script with --continue flag"
    exit 0
else
    echo "✅ NVIDIA drivers already installed"
fi

# Docker setup
echo "🐳 Setting up Docker..."

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    
    # Add Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    echo "✅ Docker installed. You may need to log out and back in."
fi

# NVIDIA Container Toolkit
echo "🔧 Setting up NVIDIA Container Toolkit..."

if ! docker run --rm --gpus all nvidia/cuda:12.1-base-ubuntu22.04 nvidia-smi &>/dev/null; then
    echo "Installing NVIDIA Container Toolkit..."
    
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    sudo systemctl restart docker
    
    # Configure Docker daemon
    sudo tee /etc/docker/daemon.json << EOF
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "50m",
        "max-file": "3"
    }
}
EOF
    
    sudo systemctl restart docker
    echo "✅ NVIDIA Container Toolkit installed"
else
    echo "✅ NVIDIA Container Toolkit already working"
fi

# Security setup
echo "🔒 Setting up security..."

# Firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow out 53,80,443  # DNS, HTTP, HTTPS
sudo ufw allow 22             # SSH
sudo ufw allow 80,443         # Web
sudo ufw --force enable

# SSH hardening
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Fail2Ban
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 2
bantime = 7200
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# SSL setup
echo "🔐 Setting up SSL certificates..."

read -p "Enter your domain name (e.g., api.yourcompany.com): " DOMAIN
read -p "Enter your email for SSL certificate: " EMAIL

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "❌ Domain and email are required for SSL setup"
    exit 1
fi

# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Create temporary nginx config for certificate challenge
sudo tee /etc/nginx/sites-available/temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/temp /etc/nginx/sites-enabled/default
sudo mkdir -p /var/www/html
sudo systemctl restart nginx

# Get SSL certificate
sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

# Project setup
echo "📁 Setting up project..."

mkdir -p ~/qwen-api/{models,cache,logs,ssl,config}
cd ~/qwen-api

# Copy certificates to project
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/key.pem
sudo chown $USER:$USER ssl/*

# Generate DH parameters
openssl dhparam -out ssl/dhparam.pem 2048

# Create environment file
tee .env << EOF
JWT_SECRET=$(openssl rand -hex 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
API_DOMAIN=$DOMAIN
ALLOWED_ORIGINS=https://$DOMAIN
LOG_LEVEL=INFO
EOF

echo ""
echo "🎉 Installation Complete!"
echo "========================="
echo ""
echo "Next steps:"
echo "1. Download all application files to ~/qwen-api/"
echo "2. Run: cd ~/qwen-api && chmod +x *.sh"
echo "3. Run: ./deploy.sh"
echo ""
echo "Your API will be available at: https://$DOMAIN"
echo ""