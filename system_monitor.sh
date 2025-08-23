#!/bin/bash
# ~/qwen-api/system_monitor.sh

LOGDIR="/var/log/qwen-api"
mkdir -p $LOGDIR

# System metrics collection
collect_metrics() {
    echo "$(date): Collecting system metrics..." >> $LOGDIR/monitor.log
    
    # GPU metrics
    nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu --format=csv >> $LOGDIR/gpu_metrics.csv
    
    # Docker metrics  
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" >> $LOGDIR/docker_metrics.log
    
    # Disk usage
    df -h >> $LOGDIR/disk_usage.log
    
    # Memory usage
    free -h >> $LOGDIR/memory_usage.log
    
    # Network connections
    ss -tuln >> $LOGDIR/network_connections.log
}

# Service health checks
health_check() {
    # API health
    if curl -sf https://localhost/health > /dev/null; then
        echo "$(date): API healthy" >> $LOGDIR/health.log
    else
        echo "$(date): API health check failed" >> $LOGDIR/health.log
        # Restart services if unhealthy
        cd ~/qwen-api && docker-compose restart
    fi
    
    # Redis health
    if docker-compose exec -T redis redis-cli ping | grep -q PONG; then
        echo "$(date): Redis healthy" >> $LOGDIR/health.log
    else
        echo "$(date): Redis health check failed" >> $
        echo "$(date): Redis health check failed" >> $LOGDIR/health.log
       cd ~/qwen-api && docker-compose restart redis
   fi
   
   # Nginx health
   if docker-compose exec -T nginx nginx -t &>/dev/null; then
       echo "$(date): Nginx healthy" >> $LOGDIR/health.log
   else
       echo "$(date): Nginx config error" >> $LOGDIR/health.log
       cd ~/qwen-api && docker-compose restart nginx
   fi
}

# Log rotation
rotate_logs() {
   find $LOGDIR -name "*.log" -size +100M -exec truncate -s 50M {} \;
   find $LOGDIR -name "*.csv" -size +100M -exec truncate -s 50M {} \;
}

# Main monitoring loop
case "$1" in
   "start")
       echo "Starting system monitor..."
       while true; do
           collect_metrics
           health_check
           rotate_logs
           sleep 300  # 5 minutes
       done
       ;;
   "once")
       collect_metrics
       health_check
       ;;
   *)
       echo "Usage: $0 {start|once}"
       ;;
esac