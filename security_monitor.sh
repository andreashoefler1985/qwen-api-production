#!/bin/bash
# ~/qwen-api/security_monitor.sh

LOG_DIR="/var/log/qwen-api"
mkdir -p $LOG_DIR

# Function to send alert (customize for your notification system)
send_alert() {
    echo "[$(date)] SECURITY ALERT: $1" | tee -a $LOG_DIR/security.log
    # Example: Send to Slack, Discord, email, etc.
    # curl -X POST -H 'Content-type: application/json' \
    #   --data '{"text":"🚨 Security Alert: '$1'"}' \
    #   YOUR_WEBHOOK_URL
}

# Monitor failed authentication attempts
monitor_auth_failures() {
    FAILED_AUTH=$(docker-compose logs qwen-api --since="5m" 2>/dev/null | \
        grep -c "401\|403\|Authentication failed" || echo "0")
    
    if [ "$FAILED_AUTH" -gt 10 ]; then
        send_alert "High number of authentication failures: $FAILED_AUTH in last 5 minutes"
    fi
}

# Monitor resource usage
monitor_resources() {
    # Check GPU memory
    GPU_MEM_USAGE=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | \
        awk -F, '{print int($1/$2*100)}')
    
    if [ "$GPU_MEM_USAGE" -gt 95 ]; then
        send_alert "GPU memory usage critical: ${GPU_MEM_USAGE}%"
    fi
    
    # Check disk space
    DISK_USAGE=$(df /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -gt 90 ]; then
        send_alert "Disk usage critical: ${DISK_USAGE}%"
    fi
}

# Monitor suspicious requests
monitor_suspicious_requests() {
    NGINX_LOG="/var/log/nginx/access.log"
    
    if [ -f "$NGINX_LOG" ]; then
        # Check for potential SQL injection attempts
        SQL_INJECTION=$(tail -100 "$NGINX_LOG" | \
            grep -i -c "union\|select\|insert\|update\|delete\|drop\|exec" || echo "0")
        
        if [ "$SQL_INJECTION" -gt 5 ]; then
            send_alert "Potential SQL injection attempts detected: $SQL_INJECTION"
        fi
        
        # Check for unusual user agents
        SUSPICIOUS_AGENTS=$(tail -100 "$NGINX_LOG" | \
            grep -i -c "sqlmap\|nikto\|nessus\|masscan\|nmap" || echo "0")
        
        if [ "$SUSPICIOUS_AGENTS" -gt 0 ]; then
            send_alert "Suspicious user agents detected: $SUSPICIOUS_AGENTS"
        fi
    fi
}

# Check service health
check_service_health() {
    if ! curl -f https://localhost/health >/dev/null 2>&1; then
        send_alert "API health check failed"
    fi
    
    if ! docker-compose ps | grep -q "Up"; then
        send_alert "One or more services are down"
    fi
}

# Main monitoring loop
while true; do
    monitor_auth_failures
    monitor_resources
    monitor_suspicious_requests
    check_service_health
    
    sleep 300  # Check every 5 minutes
done