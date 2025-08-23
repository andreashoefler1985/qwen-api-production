# ~/qwen-api/auth.py
import jwt
import hashlib
import secrets
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import redis.asyncio as redis
from redis.asyncio import Redis
import os
import logging

logger = logging.getLogger(__name__)

# JWT Configuration
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_hex(32))
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 24

security = HTTPBearer()

class APIKeyManager:
    def __init__(self):
        self.redis_client: Optional[Redis] = None
        
    async def get_redis(self) -> Redis:
        if not self.redis_client:
            password = os.getenv("REDIS_PASSWORD", "")
            self.redis_client = redis.Redis(
                host='redis', 
                port=6379, 
                db=1, 
                password=password,
                decode_responses=True
            )
        return self.redis_client
        
    async def create_api_key(self, user_id: str, permissions: Optional[List[str]] = None) -> str:
        """Create hashed API key"""
        raw_key = secrets.token_hex(32)
        hashed_key = hashlib.sha256(raw_key.encode()).hexdigest()
        
        key_data = {
            "user_id": user_id,
            "permissions": ",".join(permissions or ["generate"]),
            "created_at": datetime.utcnow().isoformat(),
            "requests_today": "0",
            "daily_limit": "1000",
            "last_reset": datetime.utcnow().date().isoformat()
        }
        
        redis_client = await self.get_redis()
        await redis_client.hset(f"apikey:{hashed_key}", mapping=key_data)  # type: ignore
        
        logger.info(f"Created API key for user: {user_id}")
        return raw_key
    
    async def verify_api_key(self, api_key: str) -> Dict:
        """Verify and get API key data"""
        # First check environment variables for direct API key match
        admin_keys = os.getenv("ADMIN_KEYS", "").split(",")
        api_keys = os.getenv("API_KEYS", "").split(",") 
        readonly_keys = os.getenv("READ_ONLY_KEYS", "").split(",")
        
        # Check against environment variables first
        if api_key in admin_keys:
            return {
                "user_id": "admin",
                "permissions": ["admin", "generate", "read"],
                "requests_today": 0,
                "daily_limit": 10000
            }
        elif api_key in api_keys:
            return {
                "user_id": "api_user", 
                "permissions": ["generate", "read"],
                "requests_today": 0,
                "daily_limit": 1000
            }
        elif api_key in readonly_keys:
            return {
                "user_id": "readonly_user",
                "permissions": ["read"],
                "requests_today": 0,
                "daily_limit": 5000
            }
        
        # Fallback to Redis-based verification
        hashed_key = hashlib.sha256(api_key.encode()).hexdigest()
        redis_client = await self.get_redis()
        key_data = await redis_client.hgetall(f"apikey:{hashed_key}")  # type: ignore
        
        if not key_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key"
            )
        
        # Reset daily counter if new day
        today = datetime.utcnow().date().isoformat()
        if key_data.get("last_reset") != today:
            await redis_client.hset(f"apikey:{hashed_key}", mapping={  # type: ignore
                "requests_today": "0",
                "last_reset": today
            })
            key_data["requests_today"] = "0"
        
        # Check daily limit
        requests_today = int(key_data.get("requests_today", 0))
        daily_limit = int(key_data.get("daily_limit", 1000))
        
        if requests_today >= daily_limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Daily limit exceeded"
            )
        
        # Increment request counter
        await redis_client.hincrby(f"apikey:{hashed_key}", "requests_today", 1)  # type: ignore
        
        return {
            "user_id": key_data["user_id"],
            "permissions": key_data["permissions"].split(","),
            "requests_today": requests_today + 1,
            "daily_limit": daily_limit
        }

    async def create_jwt_token(self, user_id: str, permissions: Optional[List[str]] = None) -> str:
        """Create JWT token"""
        payload = {
            "user_id": user_id,
            "permissions": permissions or ["generate"],
            "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS),
            "iat": datetime.utcnow()
        }
        return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

api_key_manager = APIKeyManager()

async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict:
    """Verify JWT or API key"""
    token = credentials.credentials
    
    try:
        # Try JWT first
        if token.startswith("eyJ"):
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            return {
                "user_id": payload["user_id"],
                "permissions": payload["permissions"],
                "token_type": "jwt"
            }
        else:
            # API Key
            result = await api_key_manager.verify_api_key(token)
            result["token_type"] = "api_key"
            return result
            
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    except Exception as e:
        logger.error(f"Token verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed"
        )

def require_permission(permission: str):
    """Decorator for permission checks"""
    def decorator(user_data: Dict = Depends(verify_token)):
        if permission not in user_data.get("permissions", []):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{permission}' required"
            )
        return user_data
    return decorator

# Optional: Admin permission check
require_admin = require_permission("admin")
require_generate = require_permission("generate")
