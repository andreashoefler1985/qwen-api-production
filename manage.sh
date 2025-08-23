#!/bin/bash
# ~/qwen-api/manage.sh

case "$1" in
    "start")
        echo "🚀 Starting Qwen API..."
        docker-compose up -d
        ;;
    "stop")
        echo "🛑 Stopping Qwen API..."
        docker-compose down
        ;;
    "restart")
        echo "🔄 Restarting Qwen API..."
        docker-compose restart
        ;;
    "logs")
        docker-compose logs -f ${2:-qwen-api}
        ;;
    "status")
        echo "📊 Service Status:"
        docker-compose ps
        echo ""
        echo "📈 Resource Usage:"
        docker stats --no-stream
        ;;
    "create-key")
        if [ -z "$2" ]; then
            echo "Usage: ./manage.sh create-key <user_id> [permissions]"
            exit 1
        fi
        PERMISSIONS=${3:-"generate"}
        API_KEY=$(docker-compose exec -T qwen-api python3 -c "
import asyncio
from auth import api_key_manager
async def create_key():
    key = await api_key_manager.create_api_key('$2', ['$PERMISSIONS'])
    print(key)
asyncio.run(create_key())
        ")
        echo "🔑 New API Key for $2: $API_KEY"
        ;;
    "backup")
        BACKUP_DIR="backup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p $BACKUP_DIR
        cp -r models cache logs $BACKUP_DIR/
        docker-compose exec redis redis-cli --rdb $BACKUP_DIR/redis_dump.rdb
        echo "💾 Backup created: $BACKUP_DIR"
        ;;
    "update")
        echo "🔄 Updating Qwen API..."
        git pull
        docker-compose build --no-cache
        docker-compose up -d
        ;;
    "monitor")
        echo "📊 Real-time monitoring (Press Ctrl+C to stop)..."
        watch -n 2 'docker stats --no-stream && echo "" && nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits'
        ;;
    *)
        echo "Qwen API Management Script"
        echo ""
        echo "Usage: ./manage.sh <command>"
        echo ""
        echo "Commands:"
        echo "  start              Start all services"
        echo "  stop               Stop all services"
        echo "  restart            Restart all services"
        echo "  logs [service]     Show logs"
        echo "  status             Show service status"
        echo "  create-key <user>  Create API key for user"
        echo "  backup             Create backup"
        echo "  update             Update and rebuild"
        echo "  monitor            Real-time monitoring"
        ;;
esac