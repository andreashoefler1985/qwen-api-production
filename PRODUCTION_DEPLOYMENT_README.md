# 🚀 Produktions-Deployment für ai.hoefler-cloud.com

## 📋 Deployment-Status

✅ **VOLLSTÄNDIG KONFIGURIERT** - Bereit für Produktion

## 🔐 Sicherheits-Features

### SSL/TLS
- ✅ Let's Encrypt SSL-Zertifikat für `ai.hoefler-cloud.com`
- ✅ TLS 1.2/1.3 mit sicheren Cipher Suites
- ✅ HSTS, OCSP Stapling aktiviert
- ✅ Automatische Zertifikat-Erneuerung

### Authentication & Authorization
- ✅ JWT-basierte Authentifizierung
- ✅ API-Key Management mit Redis
- ✅ Rate Limiting (60 req/min, 5 login/min)
- ✅ Daily API Limits (1000 requests/Tag)

### Server-Härtung
- ✅ Docker Security (read-only, no-new-privileges, dropped capabilities)
- ✅ Fail2Ban für automatisches IP-Blocking
- ✅ UFW Firewall (nur 22, 80, 443 offen)
- ✅ Security Headers (CSP, HSTS, X-Frame-Options, etc.)

### Monitoring & Backup
- ✅ Strukturiertes JSON-Logging
- ✅ Health Checks für alle Services
- ✅ Tägliche automatische Backups
- ✅ Log Rotation und Retention

## 🔑 API-Keys (WICHTIG!)

**Admin API-Key:** `ak_admin_nhghFm8FHSHa3PUMCS60vrJnJLhr0M-GTZAG8td8b_Y`
- Vollzugriff auf alle Endpunkte
- User Management, System Administration

**API-Key:** `ak_api_AVLX3VL9IB73YSVqmCVlJ8XpGXfYJZjWG3bXM6_4Z0s`
- Standard API-Operationen
- Text-Generierung, Chat-Endpunkte

**Read-Only-Key:** `ak_ro_5BHVXG2MxweMd-ZZMguEDkAc78plTwUzmNVHvJEWEdg`
- Nur Lesezugriff
- Status, Health-Checks, Metrics

> ⚠️ **SICHERHEITSHINWEIS:** Speichere diese Keys sicher und lösche `api_keys_*.txt` nach dem Kopieren!

## 🌐 API-Endpunkte

### Base URL
```
https://ai.hoefler-cloud.com
```

### Verfügbare Endpunkte
```
GET  /health                    # Health Check (öffentlich)
POST /api/auth/login           # Authentifizierung 
POST /api/auth/token           # Token-Erneuerung
POST /api/generate             # Text-Generierung (API-Key erforderlich)
POST /api/chat                 # Chat-Interface (API-Key erforderlich)
GET  /metrics                  # System-Metriken (nur lokal)
```

### Authentifizierung
```bash
# Mit API-Key
curl -H "Authorization: Bearer YOUR_API_KEY" https://ai.hoefler-cloud.com/api/generate

# Mit JWT Token
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" https://ai.hoefler-cloud.com/api/generate
```

## 🚀 Deployment-Kommandos

### Produktions-Deployment starten
```bash
chmod +x deploy-production.sh
./deploy-production.sh
```

### Services verwalten
```bash
# Status anzeigen
docker-compose -f docker-compose.production.yml ps

# Logs anzeigen
docker-compose -f docker-compose.production.yml logs -f

# Services neustarten
docker-compose -f docker-compose.production.yml restart

# Services stoppen
docker-compose -f docker-compose.production.yml down
```

### SSL-Zertifikat erneuern
```bash
chmod +x ssl_setup.sh
./ssl_setup.sh
```

### Neue API-Keys generieren
```bash
python3 generate_secure_tokens.py
```

## 📊 Monitoring

### Health Check
```bash
curl https://ai.hoefler-cloud.com/health
```

### Service Status
```bash
docker-compose -f docker-compose.production.yml ps
```

### Logs einsehen
```bash
# Nginx Logs
docker-compose -f docker-compose.production.yml logs nginx

# API Logs  
docker-compose -f docker-compose.production.yml logs qwen-api

# Fail2Ban Status
sudo fail2ban-client status
```

## 💾 Backup & Recovery

### Backup ausführen
```bash
./backup.sh
```

### Backup-Dateien
```
./backups/
├── redis_YYYYMMDD_HHMMSS.rdb        # Redis-Daten
├── ssl_YYYYMMDD_HHMMSS.tar.gz       # SSL-Zertifikate  
├── config_YYYYMMDD_HHMMSS.tar.gz    # Konfigurationsdateien
├── logs_YYYYMMDD_HHMMSS.tar.gz      # Anwendungslogs
└── full_system_YYYYMMDD_HHMMSS.tar.gz # Komplettes System
```

### Recovery
```bash
# SSL-Zertifikate wiederherstellen
tar -xzf backups/ssl_YYYYMMDD_HHMMSS.tar.gz

# Konfiguration wiederherstellen  
tar -xzf backups/config_YYYYMMDD_HHMMSS.tar.gz

# Redis-Daten wiederherstellen
docker cp backups/redis_YYYYMMDD_HHMMSS.rdb redis-cache:/data/dump.rdb
docker-compose -f docker-compose.production.yml restart redis
```

## 🔧 Konfiguration

### Environment-Variablen (.env.production)
- ✅ JWT_SECRET: Kryptographisch sicher generiert
- ✅ REDIS_PASSWORD: Stark verschlüsseltes Passwort
- ✅ API_DOMAIN: ai.hoefler-cloud.com
- ✅ ALLOWED_ORIGINS: HTTPS-only
- ✅ LOG_LEVEL: INFO für Produktion

### Docker-Services
- **nginx:** Reverse Proxy mit SSL-Terminierung
- **qwen-api:** Hauptanwendung mit GPU-Unterstützung
- **redis:** Session-Store und Caching
- **fail2ban:** Intrusion Prevention System
- **log-monitor:** Log-Aggregation
- **backup:** Automatisches Backup-System

## 🚨 Troubleshooting

### Service startet nicht
```bash
# Logs überprüfen
docker-compose -f docker-compose.production.yml logs SERVICE_NAME

# Container-Status
docker ps -a

# System-Ressourcen
docker system df
nvidia-smi
```

### SSL-Probleme
```bash
# Zertifikat-Status
openssl x509 -in ssl/cert.pem -text -noout

# Nginx-Konfiguration testen
docker exec nginx-proxy nginx -t

# Let's Encrypt erneuern
sudo certbot renew --dry-run
```

### API nicht erreichbar
```bash
# Nginx-Status
curl -I https://ai.hoefler-cloud.com

# API-Health-Check
curl https://ai.hoefler-cloud.com/health

# Firewall-Status
sudo ufw status
```

## 📞 Support & Wartung

### Regelmäßige Wartung
- [ ] **Wöchentlich:** Log-Dateien prüfen
- [ ] **Monatlich:** Security-Updates installieren  
- [ ] **Quartalsweise:** API-Keys rotieren
- [ ] **Halbjährlich:** SSL-Zertifikat-Health-Check

### Kritische Pfade
```
/etc/nginx/nginx.conf          # Nginx-Konfiguration
/etc/letsencrypt/live/         # SSL-Zertifikate
./ssl/                         # Lokale SSL-Kopien
./logs/                        # Anwendungslogs
./backups/                     # Backup-Dateien
```

---

## 🎉 Deployment erfolgreich!

Ihre AI API ist jetzt sicher und produktionsbereit unter:
**https://ai.hoefler-cloud.com**

**Nächste Schritte:**
1. DNS für `ai.hoefler-cloud.com` konfigurieren
2. API-Keys in Client-Anwendungen einbauen
3. SSL-Rating testen: https://www.ssllabs.com/ssltest/
4. Monitoring-Alerts einrichten
5. Backup-Strategie testen

---
*Generiert am: 2025-08-23 04:20*
