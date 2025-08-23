# 🚀 Qwen AI API Production Server

[![Docker](https://img.shields.io/badge/Docker-Production--Ready-blue.svg)](https://www.docker.com/)
[![SSL](https://img.shields.io/badge/SSL-Let's%20Encrypt-green.svg)](https://letsencrypt.org/)
[![Security](https://img.shields.io/badge/Security-Hardened-red.svg)](https://github.com/andreashoefler1985/qwen-api-production)

**Production-ready Qwen AI API Server** mit Docker, SSL, Authentication und Monitoring für **ai.hoefler-cloud.com**.

## 🎯 Features

### 🔒 **Sicherheit & Härtung**
- ✅ SSL/TLS Verschlüsselung mit Let's Encrypt
- ✅ API-Key Authentication (JWT + Redis)
- ✅ Rate Limiting (60 requests/min pro IP)
- ✅ Fail2ban Intrusion Prevention
- ✅ Security Headers (HSTS, CSP, X-Frame-Options)
- ✅ Container Isolation & Non-Root Users

### 🐳 **Containerisierung & Orchestrierung**
- ✅ Docker Compose Production Setup
- ✅ Alpine Linux für minimale Attack Surface
- ✅ Multi-Service Architecture (API, nginx, Redis, Monitoring)
- ✅ Persistent Volumes & Health Checks
- ✅ Graceful Shutdown & Restart Policies

### 🤖 **AI API Capabilities**
- ✅ Qwen Large Language Model Integration
- ✅ GPU Support (NVIDIA CUDA)
- ✅ Chat Completions API (OpenAI-kompatibel)
- ✅ Streaming Responses
- ✅ Token Management & Usage Tracking

### 📊 **Monitoring & Logging**
- ✅ Prometheus Metrics & Health Endpoints
- ✅ Promtail Log Aggregation
- ✅ Grafana Dashboard Integration
- ✅ Real-time Service Monitoring
- ✅ Error Tracking & Performance Metrics

## 🚀 Quick Start

### 1. Repository klonen
```bash
git clone https://github.com/andreashoefler1985/qwen-api-production.git
cd qwen-api-production
```

### 2. DNS-Konfiguration
```bash
# Domain auf Server-IP zeigen lassen
dig ai.hoefler-cloud.com  # sollte auf Ihre Server-IP zeigen
```

### 3. Production-Deployment
```bash
# Dateien auf Server kopieren
scp -r . root@YOUR_SERVER:/opt/qwen-api/

# SSH auf Server und Deployment starten
ssh root@YOUR_SERVER
cd /opt/qwen-api
chmod +x deploy-production-final.sh
./deploy-production-final.sh
```

### 4. SSL-Zertifikate einrichten
```bash
./ssl_setup.sh ai.hoefler-cloud.com
```

## 🔑 API Usage

### Chat Completion Beispiel
```bash
curl -X POST https://ai.hoefler-cloud.com/api/v1/chat \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Erkläre Quantencomputing"}
    ],
    "max_tokens": 1000,
    "temperature": 0.7
  }'
```

### Health Check
```bash
curl https://ai.hoefler-cloud.com/api/health
```

### Metrics
```bash
curl https://ai.hoefler-cloud.com/api/metrics
```

## 📁 Projektstruktur

```
qwen-api-production/
├── 🐳 Docker & Container
│   ├── docker-compose.production.yml  # Production Container Setup
│   ├── Dockerfile                     # Qwen API Container
│   └── nginx.conf                     # Reverse Proxy Config
├── 🔧 Deployment & Management
│   ├── deploy-production-final.sh     # Hauptdeployment-Script
│   ├── restart-production.sh          # Service-Restart
│   └── manage.sh                      # Service-Management
├── 🔒 Sicherheit & SSL
│   ├── ssl_setup.sh                   # Let's Encrypt SSL
│   ├── fail2ban_setup.sh             # Intrusion Prevention
│   └── firewall_setup.sh             # Firewall-Regeln
├── 📊 Monitoring & Logs
│   ├── promtail-config.yml           # Log-Aggregation
│   └── system_monitor.sh             # System-Monitoring
├── 🤖 AI API Core
│   ├── api_server.py                 # Haupt-API-Server
│   ├── auth.py                       # Authentication
│   └── requirements.txt              # Python Dependencies
├── ⚙️ Konfiguration
│   ├── .env.production               # Production Environment
│   └── .gitignore                    # Git Ignore Rules
└── 📖 Dokumentation
    ├── README.md                     # Diese Datei
    ├── FINAL_DEPLOYMENT_GUIDE.md     # Detaillierte Anleitung
    └── ARCHITECTURE.md               # System-Architektur
```

## 🛡️ Sicherheitsfeatures

### **Network Security**
- nginx Reverse Proxy mit SSL-Termination
- Rate Limiting & DDoS Protection
- Security Headers (HSTS, CSP, X-Frame-Options)
- Firewall-Regeln für minimale Angriffsfläche

### **Application Security**
- JWT-basierte API-Key Authentication
- Redis Session Management
- Input Validation & Sanitization
- Secure Error Handling (keine Info-Leaks)

### **Infrastructure Security**
- Container Isolation mit Non-Root Users
- Fail2ban Intrusion Detection
- Automated Security Updates
- Encrypted Data at Rest & in Transit

## 📊 Service Endpoints

Nach erfolgreichem Deployment verfügbar:

| Service | URL | Beschreibung |
|---------|-----|--------------|
| **Chat API** | `https://ai.hoefler-cloud.com/api/v1/chat` | Haupt-AI-Chat-Endpoint |
| **Health Check** | `https://ai.hoefler-cloud.com/api/health` | Service-Status |
| **Metrics** | `https://ai.hoefler-cloud.com/api/metrics` | Prometheus-Metriken |
| **Grafana** | `https://ai.hoefler-cloud.com:3000` | Log-Dashboard |

## 🔧 Troubleshooting

### Services-Status prüfen
```bash
docker-compose -f docker-compose.production.yml ps
docker-compose -f docker-compose.production.yml logs -f
```

### Häufige Probleme

**SSL-Zertifikat-Probleme:**
```bash
# Zertifikat erneuern
certbot renew --nginx
systemctl reload nginx
```

**Container nicht erreichbar:**
```bash
# Services neustarten
./restart-production.sh

# Einzelne Services debuggen
docker-compose -f docker-compose.production.yml logs qwen-api
```

**API-Authentication-Fehler:**
```bash
# API-Keys prüfen
grep API_KEY .env.production
```

## 🚧 Wartung & Updates

### Backup erstellen
```bash
./backup.sh
```

### System-Updates
```bash
./update.sh
```

### Performance-Optimierung
```bash
./optimize.sh
```

## 📈 Monitoring

### Verfügbare Metriken
- Request Count & Response Times
- GPU Memory Usage & Utilization
- Container Resource Usage (CPU, Memory, Disk)
- API Error Rates & Status Codes
- Authentication Success/Failure Rates

### Log-Aggregation
- nginx Access/Error Logs
- Qwen API Application Logs
- System Security Events
- Container Runtime Logs

## 🤝 Contributing

1. Fork das Repository
2. Feature Branch erstellen: `git checkout -b feature/neue-funktion`
3. Changes committen: `git commit -m 'Add neue Funktion'`
4. Branch pushen: `git push origin feature/neue-funktion`
5. Pull Request erstellen

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) Datei für Details.

## 🆘 Support

Bei Fragen oder Problemen:
- **Issues**: [GitHub Issues](https://github.com/andreashoefler1985/qwen-api-production/issues)
- **Dokumentation**: [FINAL_DEPLOYMENT_GUIDE.md](FINAL_DEPLOYMENT_GUIDE.md)
- **Wiki**: [Project Wiki](https://github.com/andreashoefler1985/qwen-api-production/wiki)

---

**⚡ Production-ready AI API Server mit Enterprise-Grade Security & Monitoring**

Made with ❤️ for robust AI deployments
