#!/bin/bash
# project_setup.sh

# Projekt Verzeichnisse erstellen
mkdir -p ~/qwen-api/{models,cache,logs,ssl,config}
cd ~/qwen-api

# Environment Datei erstellen
tee .env << EOF
JWT_SECRET=$(openssl rand -hex 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
API_DOMAIN=your-domain.com
ALLOWED_ORIGINS=https://your-allowed-domain.com
LOG_LEVEL=INFO
EOF

echo "Project structure created!"