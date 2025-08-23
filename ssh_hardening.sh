#!/bin/bash
# ssh_hardening.sh

# SSH Konfiguration härten
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

sudo tee -a /etc/ssh/sshd_config << EOF

# Security Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2
X11Forwarding no
UsePAM yes
EOF

# SSH Service neustarten
sudo systemctl restart ssh

echo "SSH hardened successfully!"