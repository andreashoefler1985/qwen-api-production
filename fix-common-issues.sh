#!/bin/bash
# ~/qwen-api/fix-common-issues.sh

fix_gpu_issues() {
    echo "🎮 Fixing GPU issues..."
    
    # Reset GPU
    sudo nvidia-smi --gpu-reset
    
    # Check NVIDIA Docker runtime
    if ! docker run --rm --gpus all nvidia/cuda:12.1-base-ubuntu22.04 nvidia-smi; then
        echo "Reinstalling NVIDIA Container Toolkit..."
        sudo apt install --reinstall nvidia-container-toolkit
        sudo systemctl restart docker
    fi
}

fix_memory_issues() {
    echo "💾 Fixing memory issues..."
    
    # Clear system cache
    sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
    
    # Restart services to free memory
    docker-compose restart
    
    # Clean Docker system
    docker system prune -f
}

fix_disk_issues() {
    echo "💿 Fixing disk space issues..."
    
    # Clean Docker
    docker system prune -a -f
    docker volume prune -f
    
    # Clean logs
    find logs/ -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    journalctl --vacuum-time=7d
    
    # Clean cache
    find cache/ -type f -mtime +1 -delete 2>/dev/null || true
}

fix_permission_issues() {
    echo "🔐 Fixing permission issues..."
    
    # Fix ownership
    sudo chown -R $USER:$USER ~/qwen-api
    chmod +x ~/qwen-api/*.sh
    
    # Fix SSL permissions
    chmod 600 ssl/*.pem
}

fix_network_issues() {
    echo "🌐 Fixing network issues..."
    
    # Restart networking
    sudo systemctl restart networking
    
    # Flush DNS
    sudo systemctl flush-dns 2>/dev/null || sudo service dns-clean restart
    
    # Reset iptables if needed
    # sudo iptables -F
    # sudo iptables -X
    # sudo iptables -t nat -F
    # sudo iptables -t nat -X
}

case "$1" in
    "gpu") fix_gpu_issues ;;
    "memory") fix_memory_issues ;;
    "disk") fix_disk_issues ;;
    "permissions") fix_permission_issues ;;
    "network") fix_network_issues ;;
    "all")
        fix_memory_issues
        fix_disk_issues
        fix_permission_issues
        fix_network_issues
        fix_gpu_issues
        ;;
    *)
        echo "Usage: $0 {gpu|memory|disk|permissions|network|all}"
        echo ""
        echo "Available fixes:"
        echo "  gpu         - Fix GPU/CUDA issues"
        echo "  memory      - Free up memory"
        echo "  disk        - Clean up disk space"
        echo "  permissions - Fix file permissions"
        echo "  network     - Reset network settings"
        echo "  all         - Apply all fixes"
        ;;
esac