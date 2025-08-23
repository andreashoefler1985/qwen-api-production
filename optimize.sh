#!/bin/bash
# ~/qwen-api/optimize.sh

echo "⚡ Optimizing Qwen API Performance..."

# GPU Performance
echo "🎮 Optimizing GPU settings..."
# Set GPU persistence mode
sudo nvidia-smi -pm 1

# Set GPU performance mode
sudo nvidia-smi -ac 1215,1410  # Adjust for your GPU

# Docker optimizations
echo "🐳 Optimizing Docker settings..."
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
    },
    "storage-driver": "overlay2",
    "storage-opts": ["overlay2.override_kernel_check=true"],
    "default-ulimits": {
        "nofile": {
            "Hard": 64000,
            "Name": "nofile",
            "Soft": 64000
        }
    }
}
EOF

# System optimizations
echo "⚙️ Optimizing system settings..."

# Increase file descriptor limits
sudo tee -a /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

# Optimize network settings
sudo tee -a /etc/sysctl.conf << EOF
# Network optimizations
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 90

# Memory optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

sudo sysctl -p

# Redis optimizations
echo "🔴 Optimizing Redis..."
docker-compose exec redis redis-cli CONFIG SET save "900 1 300 10 60 10000"
docker-compose exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
docker-compose exec redis redis-cli CONFIG SET timeout 300
docker-compose exec redis redis-cli CONFIG SET tcp-keepalive 300

echo "✅ Optimizations applied!"
echo "Restart required for some changes to take effect."
echo "Run 'sudo reboot' when convenient."