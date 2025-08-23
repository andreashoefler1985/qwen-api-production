# ~/qwen-api/api_server.py
import asyncio
import hashlib
import json
import logging
import os
import re
import time
from contextlib import asynccontextmanager
from typing import Dict, List, Optional

import bleach
import redis.asyncio as redis
import torch
from cachetools import TTLCache
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
from pydantic import BaseModel, Field, validator
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from tenacity import retry, stop_after_attempt, wait_exponential
from transformers import AutoModelForCausalLM, AutoTokenizer

from auth import verify_token, require_generate, require_admin, api_key_manager

# Logging Setup
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO")),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Metrics
REQUEST_COUNT = Counter('qwen_requests_total', 'Total requests', ['endpoint', 'status'])
REQUEST_DURATION = Histogram('qwen_request_duration_seconds', 'Request duration')
CACHE_HITS = Counter('qwen_cache_hits_total', 'Cache hits')
CACHE_MISSES = Counter('qwen_cache_misses_total', 'Cache misses')

class QwenAPI:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.redis_client = None
        self.memory_cache = TTLCache(maxsize=1000, ttl=3600)  # 1h TTL
        
    async def get_redis(self):
        if not self.redis_client:
            password = os.getenv("REDIS_PASSWORD", "")
            self.redis_client = redis.Redis(
                host='redis', 
                port=6379, 
                db=0, 
                password=password,
                decode_responses=True
            )
        return self.redis_client
        
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def load_model(self):
        """Load Qwen model with retry logic"""
        try:
            model_path = "Qwen/Qwen2.5-Coder-32B-Instruct"
            
            logger.info(f"Loading model on {self.device}")
            
            # Load tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(
                model_path,
                trust_remote_code=True,
                cache_dir="/app/models"
            )
            
            # Load model with optimizations
            self.model = AutoModelForCausalLM.from_pretrained(
                model_path,
                device_map="auto",
                torch_dtype=torch.bfloat16,
                trust_remote_code=True,
                cache_dir="/app/models",
                low_cpu_mem_usage=True,
                attn_implementation="flash_attention_2" if torch.cuda.is_available() else "eager"
            )
            
            # Compile model for faster inference (PyTorch 2.0+)
            if hasattr(torch, 'compile'):
                self.model = torch.compile(self.model)
            
            logger.info("Model loaded successfully")
            
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            raise

    def get_cache_key(self, prompt: str, **kwargs) -> str:
        """Generate cache key from prompt and parameters"""
        cache_data = {"prompt": prompt, **kwargs}
        return hashlib.md5(json.dumps(cache_data, sort_keys=True).encode()).hexdigest()

    async def get_from_cache(self, cache_key: str) -> Optional[str]:
        """Get response from cache (Memory first, then Redis)"""
        try:
            # Try memory cache first (fastest)
            if cache_key in self.memory_cache:
                CACHE_HITS.inc()
                return self.memory_cache[cache_key]
            
            # Try Redis cache
            redis_client = await self.get_redis()
            cached = await redis_client.get(cache_key)
            if cached:
                # Store in memory cache for faster access
                self.memory_cache[cache_key] = cached
                CACHE_HITS.inc()
                return cached
                
        except Exception as e:
            logger.warning(f"Cache read error: {e}")
        
        CACHE_MISSES.inc()
        return None

    async def store_in_cache(self, cache_key: str, response: str):
        """Store response in both caches"""
        try:
            # Store in memory cache
            self.memory_cache[cache_key] = response
            
            # Store in Redis with 24h TTL
            redis_client = await self.get_redis()
            await redis_client.setex(cache_key, 86400, response)
            
        except Exception as e:
            logger.warning(f"Cache write error: {e}")

    @torch.inference_mode()
    async def generate_response(
        self, 
        prompt: str, 
        max_tokens: int = 2048,
        temperature: float = 0.1,
        top_p: float = 0.95
    ) -> str:
        """Generate response with caching"""
        
        # Check if model and tokenizer are loaded
        if self.model is None or self.tokenizer is None:
            raise HTTPException(status_code=503, detail="Model not loaded yet")
        
        cache_key = self.get_cache_key(
            prompt=prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p
        )
        
        # Check cache first
        cached_response = await self.get_from_cache(cache_key)
        if cached_response:
            return cached_response

        try:
            # Prepare input
            messages = [{"role": "user", "content": prompt}]
            text = self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
            
            inputs = self.tokenizer(text, return_tensors="pt").to(self.device)
            
            # Generate
            with torch.cuda.amp.autocast():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=max_tokens,
                    temperature=temperature,
                    top_p=top_p,
                    do_sample=temperature > 0,
                    pad_token_id=self.tokenizer.eos_token_id,
                    eos_token_id=self.tokenizer.eos_token_id,
                )
            
            # Decode response
            response = self.tokenizer.decode(
                outputs[0][inputs.input_ids.shape[-1]:], 
                skip_special_tokens=True
            )
            
            # Store in cache
            await self.store_in_cache(cache_key, response)
            
            return response
            
        except Exception as e:
            logger.error(f"Generation error: {e}")
            raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

# Global API instance
qwen_api = QwenAPI()

# Rate Limiting
limiter = Limiter(key_func=get_remote_address)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    logger.info("Starting Qwen API Server...")
    await qwen_api.load_model()
    logger.info("Server ready!")
    yield
    logger.info("Shutting down...")

app = FastAPI(
    title="Secure Qwen 2.5 Coder API",
    description="Production-ready secured Qwen API with caching",
    version="1.0.0",
    docs_url=None,  # Disable Swagger in production
    redoc_url=None,
    lifespan=lifespan
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Security Middleware
allowed_hosts = [os.getenv("API_DOMAIN", "localhost")]
app.add_middleware(
    TrustedHostMiddleware, 
    allowed_hosts=allowed_hosts
)

allowed_origins = os.getenv("ALLOWED_ORIGINS", "").split(",")
if allowed_origins and allowed_origins[0]:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=True,
        allow_methods=["POST", "GET"],
        allow_headers=["Authorization", "Content-Type"],
    )

# Input Sanitization
def sanitize_input(text: str) -> str:
    """Sanitize user input"""
    if len(text) > 50000:  # Increased for coding tasks
        raise HTTPException(status_code=400, detail="Input too long")
    
    # Remove potential dangerous patterns
    dangerous_patterns = [
        r'<script.*?>.*?</script>',
        r'javascript:',
        r'on\w+\s*=',
    ]
    
    for pattern in dangerous_patterns:
        if re.search(pattern, text, re.IGNORECASE | re.DOTALL):
            raise HTTPException(status_code=400, detail="Invalid input detected")
    
    return text

# Request Models
class GenerateRequest(BaseModel):
    prompt: str
    max_tokens: int = Field(default=2048, ge=1, le=8192)
    temperature: float = Field(default=0.1, ge=0.0, le=2.0)
    top_p: float = Field(default=0.95, ge=0.1, le=1.0)
    
    @validator('prompt')
    def validate_prompt(cls, v):
        return sanitize_input(v)

class GenerateResponse(BaseModel):
    response: str
    cached: bool = False
    generation_time: float
    user_id: str

# Security Headers Middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response

# API Endpoints
@app.post("/v1/generate", response_model=GenerateResponse)
@limiter.limit("5/minute")
async def generate_text(
    request: Request,
    data: GenerateRequest,
    user_data: Dict = Depends(require_generate)
):
    """Generate text completion"""
    start_time = time.time()
    
    try:
        REQUEST_COUNT.labels(endpoint="generate", status="started").inc()
        
        response = await qwen_api.generate_response(
            prompt=data.prompt,
            max_tokens=data.max_tokens,
            temperature=data.temperature,
            top_p=data.top_p
        )
        
        generation_time = time.time() - start_time
        REQUEST_DURATION.observe(generation_time)
        REQUEST_COUNT.labels(endpoint="generate", status="success").inc()
        
        # Log for audit
        logger.info(f"Generation request from user {user_data['user_id']} - {generation_time:.2f}s")
        
        return GenerateResponse(
            response=response,
            generation_time=generation_time,
            user_id=user_data["user_id"]
        )
        
    except Exception as e:
        REQUEST_COUNT.labels(endpoint="generate", status="error").inc()
        logger.error(f"Generation error for user {user_data['user_id']}: {e}")
        raise HTTPException(status_code=500, detail="Generation failed")

@app.post("/v1/chat/completions")
@limiter.limit("5/minute")
async def chat_completions(
    request: Request,
    chat_request: dict,
    user_data: Dict = Depends(require_generate)
):
    """OpenAI-compatible chat endpoint"""
    try:
        messages = chat_request.get("messages", [])
        if not messages:
            raise HTTPException(status_code=400, detail="No messages provided")
        
        # Extract the last user message
        user_message = ""
        for msg in reversed(messages):
            if msg.get("role") == "user":
                user_message = msg.get("content", "")
                break
        
        if not user_message:
            raise HTTPException(status_code=400, detail="No user message found")
        
        # Sanitize input
        user_message = sanitize_input(user_message)
        
        response = await qwen_api.generate_response(
            prompt=user_message,
            max_tokens=chat_request.get("max_tokens", 2048),
            temperature=chat_request.get("temperature", 0.1),
            top_p=chat_request.get("top_p", 0.95)
        )
        
        return {
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": response
                },
                "finish_reason": "stop"
            }],
            "model": "qwen2.5-coder-32b",
            "usage": {
                "prompt_tokens": len(user_message.split()),
                "completion_tokens": len(response.split()),
                "total_tokens": len(user_message.split()) + len(response.split())
            }
        }
        
    except Exception as e:
        logger.error(f"Chat completion error for user {user_data['user_id']}: {e}")
        raise HTTPException(status_code=500, detail="Chat completion failed")

# Admin endpoints
@app.post("/admin/create-api-key")
async def create_api_key(
    key_request: dict,
    user_data: Dict = Depends(require_admin)
):
    """Create new API key (Admin only)"""
    try:
        user_id = key_request.get("user_id")
        permissions = key_request.get("permissions", ["generate"])
        
        if not user_id:
            raise HTTPException(status_code=400, detail="user_id required")
        
        api_key = await api_key_manager.create_api_key(user_id, permissions)
        
        logger.info(f"API key created for {user_id} by admin {user_data['user_id']}")
        
        return {
            "api_key": api_key,
            "user_id": user_id,
            "permissions": permissions,
            "created_by": user_data["user_id"]
        }
        
    except Exception as e:
        logger.error(f"API key creation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to create API key")

# Health and monitoring
@app.get("/health")
async def health_check():
    """Public health check"""
    return {
        "status": "healthy",
        "model_loaded": qwen_api.model is not None,
        "device": qwen_api.device,
        "timestamp": time.time()
    }

@app.get("/stats")
async def get_stats(user_data: Dict = Depends(verify_token)):
    """User statistics"""
    try:
        redis_client = await qwen_api.get_redis()
        redis_connected = await redis_client.ping()
    except:
        redis_connected = False
    
    gpu_info = None
    if torch.cuda.is_available():
        gpu_info = {
            "name": torch.cuda.get_device_name(0),
            "memory_allocated": torch.cuda.memory_allocated(0),
            "memory_reserved": torch.cuda.memory_reserved(0),
            "memory_total": torch.cuda.get_device_properties(0).total_memory
        }
    
    return {
        "user_id": user_data["user_id"],
        "requests_today": user_data.get("requests_today", 0),
        "daily_limit": user_data.get("daily_limit", 1000),
        "cache_size": len(qwen_api.memory_cache),
        "redis_connected": redis_connected,
        "device": qwen_api.device,
        "gpu_info": gpu_info
    }

@app.get("/admin/metrics")
async def metrics(user_data: Dict = Depends(require_admin)):
   """Prometheus metrics (Admin only)"""
   return Response(generate_latest(), media_type="text/plain")

if __name__ == "__main__":
   import uvicorn
   uvicorn.run(
       "api_server:app",
       host="0.0.0.0",
       port=8000,
       workers=1,
       log_level="info"
   )
