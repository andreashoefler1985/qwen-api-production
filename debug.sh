#!/bin/bash
# ~/qwen-api/debug.sh

echo "🔍 Qwen API Debug Information"
echo "============================="

echo ""
echo "📊 System Information:"
echo "---------------------"
uname -a
cat /etc/os-release | grep PRETTY_NAME
free -h
df -h /
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv

echo ""
echo "🐳 Docker Information:"
echo "--------------------"
docker --version
docker-compose --version
docker system df

echo ""
echo "📋 Service Status:"
echo "-----------------"
docker-compose ps

echo ""
echo "🔥 Recent Errors (last 100 lines):"
echo "----------------------------------"
echo "=== API Logs ==="
docker-compose logs --tail=100 qwen-api | grep -i error || echo "No errors found"

echo ""
echo "=== Nginx Logs ==="
docker-compose logs --tail=100 nginx | grep -i error || echo "No errors found"

echo ""
echo "=== Redis Logs ==="
docker-compose logs --tail=100 redis | grep -i error || echo "No errors found"

echo ""
echo "🌐 Network Connectivity:"
echo "------------------------"
curl -I https://huggingface.co 2>/dev/null | head -1 || echo "❌ Cannot reach Hugging Face"
docker-compose exec qwen-api curl -f http://redis:6379 2>/dev/null && echo "✅ Redis connection OK" || echo "❌ Redis connection failed"

echo ""
echo "💾 Storage Usage:"
echo "----------------"
echo "Models directory:"
du -sh models/ 2>/dev/null || echo "No models directory"
echo "Cache directory:"
du -sh cache/ 2>/dev/null || echo "No cache directory"
echo "Logs directory:"
du -sh logs/ 2>/dev/null || echo "No logs directory"

echo ""
echo "🔧 Configuration:"
echo "----------------"
echo "Environment variables (sensitive data hidden):"
cat .env | sed 's/=.*$/=***HIDDEN***/' || echo "No .env file found"

echo ""
echo "🏥 Health Status:"
echo "----------------"
python3 test_api.py --quick 2>/dev/null && echo "✅ API responding" || echo "❌ API not responding"