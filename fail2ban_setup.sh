#!/bin/bash
# fail2ban_setup.sh

# Fail2Ban installieren
sudo apt install -y fail2ban

# Konfiguration
sudo tee /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

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

echo "Fail2Ban configured successfully!"