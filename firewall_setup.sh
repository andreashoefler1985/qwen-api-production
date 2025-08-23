#!/bin/bash
# firewall_setup.sh

# UFW Firewall konfigurieren
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default deny outgoing

# Ausgehende Verbindungen erlauben
sudo ufw allow out 53      # DNS
sudo ufw allow out 80,443  # HTTP/HTTPS
sudo ufw allow out 123     # NTP

# Eingehende Verbindungen
sudo ufw allow 22          # SSH
sudo ufw allow 80,443      # Web

# Firewall aktivieren
sudo ufw --force enable

echo "Firewall configured successfully!"