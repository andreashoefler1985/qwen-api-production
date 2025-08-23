# ~/qwen-api/api_server_14b.py
import asyncio
import hashlib
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from typing import Dict, Optional

import torch
from cachetools import TTLCache
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
from transformers import AutoModelForCausalLM, AutoTokenizer
from tenacity import retry, stop_after_attempt, wait_exponential

from auth import verify_token, require_generate

# Logging Setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class QwenAPI14B:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.memory_cache = TTLCache(maxsize=500, ttl=3600)  # Smaller cache for 14B
        
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
    async def load_model(self):
        """Load Qwen 2.5 14B Coder model"""
        try:
            # Verwende 14B Modell statt 32B
            model_path = "Qwen/Qwen2.5-Coder-14B-Instruct"
            
            logger.info(f"Loading Qwen 2.5 Coder 14B on {self.device}")
            
            # Load tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(
                model_path,
                trust_remote_code=True,
                cache_dir="/app/models"
            )
            
            # Load 14B model with optimizations for smaller GPU memory
            self.model = AutoModelForCausalLM.from_pretrained(
                model_path,
                device_map="auto",
                torch_dtype=torch.bfloat16,  # Use bfloat16 for memory efficiency
                trust_remote_code=True,
                cache_dir="/app/models",
                low_cpu_mem_usage=True,
                # Optimizations für 14B Modell
                max_memory={0: "20GB", "cpu": "30GB"},  # Adjust based on your GPU
                load_in_8bit=False,  # Set to True if memory issues
                attn_implementation="flash_attention_2" if torch.cuda.is_available() else "eager"
            )
            
            logger.info(f"Qwen 2.5 Coder 14B loaded successfully")
            logger.info(f"Model device: {next(self.model.parameters()).device}")
            
        except Exception as e:
            logger.error(f"Error loading Qwen 2.5 Coder 14B: {e}")
            raise

    def get_cache_key(self, prompt: str, **kwargs) -> str:
        """Generate cache key from prompt and parameters"""
        cache_data = {"prompt": prompt, **kwargs}
        return hashlib.md5(json.dumps(cache_data, sort_keys=True).encode()).hexdigest()

    @torch.inference_mode()
    async def generate_response(
        self, 
        prompt: str, 
        max_tokens: int = 2048,
        temperature: float = 0.1,
        top_p: float = 0.95
    ) -> str:
        """Generate response with Qwen 2.5 14B"""
        
        cache_key = self.get_cache_key(
            prompt=prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p
        )
        
        # Check cache first
        if cache_key in self.memory_cache:
            logger.info("Cache hit")
            return self.memory_cache[cache_key]

        try:
            # Prepare input für 14B Modell
            messages = [{"role": "user", "content": prompt}]
            text = self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
            
            inputs = self.tokenizer(text, return_tensors="pt").to(self.device)
            
            # Generate with 14B optimizations
            with torch.cuda.amp.autocast():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=max_tokens,
                    temperature=temperature,
                    top_p=top_p,
                    do_sample=temperature > 0,
                    pad_token_id=self.tokenizer.eos_token_id,
                    eos_token_id=self.tokenizer.eos_token_id,
                    repetition_penalty=1.1,  # Prevent repetition
                    length_penalty=1.0
                )
            
            # Decode response
            response = self.tokenizer.decode(
                outputs[0][inputs.input_ids.shape[-1]:], 
                skip_special_tokens=True
            )
            
            # Store in cache
            self.memory_cache[cache_key] = response
            
            return response
            
        except Exception as e:
            logger.error(f"Generation error: {e}")
            raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

# Global API instance
qwen_api = QwenAPI14B()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    logger.info("Starting Qwen 2.5 Coder 14B API Server...")
    await qwen_api.load_model()
    logger.info("Server ready!")
    yield
    logger.info("Shutting down...")

app = FastAPI(
    title="Qwen 2.5 Coder 14B API",
    description="Production-ready Qwen 2.5 Coder 14B API",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    lifespan=lifespan
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "").split(","),
    allow_credentials=True,
    allow_methods=["POST", "GET"],
    allow_headers=["Authorization", "Content-Type"],
)

# Request Models
class GenerateRequest(BaseModel):
    prompt: str
    max_tokens: int = Field(default=2048, ge=1, le=4096)
    temperature: float = Field(default=0.1, ge=0.0, le=2.0)
    top_p: float = Field(default=0.95, ge=0.1, le=1.0)

class GenerateResponse(BaseModel):
    response: str
    model: str = "qwen2.5-coder-14b"
    generation_time: float

# API Endpoints
@app.post("/v1/generate", response_model=GenerateResponse)
async def generate_text(
    request: GenerateRequest,
    user_data: Dict = Depends(require_generate)
):
    """Generate text with Qwen 2.5 Coder 14B"""
    start_time = time.time()
    
    try:
        response = await qwen_api.generate_response(
            prompt=request.prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p
        )
        
        generation_time = time.time() - start_time
        
        logger.info(f"Generation completed in {generation_time:.2f}s for user {user_data['user_id']}")
        
        return GenerateResponse(
            response=response,
            generation_time=generation_time
        )
        
    except Exception as e:
        logger.error(f"Generation error: {e}")
        raise HTTPException(status_code=500, detail="Generation failed")

@app.post("/v1/chat/completions")
async def chat_completions(
    chat_request: dict,
    user_data: Dict = Depends(require_generate)
):
    """OpenAI-compatible chat endpoint für Qwen 2.5 14B"""
    try:
        messages = chat_request.get("messages", [])
        if not messages:
            raise HTTPException(status_code=400, detail="No messages provided")
        
        # Extract user message
        user_message = ""
        for msg in reversed(messages):
            if msg.get("role") == "user":
                user_message = msg.get("content", "")
                break
        
        if not user_message:
            raise HTTPException(status_code=400, detail="No user message found")
        
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
            "model": "qwen2.5-coder-14b",
            "usage": {
                "prompt_tokens": len(user_message.split()),
                "completion_tokens": len(response.split()),
                "total_tokens": len(user_message.split()) + len(response.split())
            }
        }
        
    except Exception as e:
        logger.error(f"Chat completion error: {e}")
        raise HTTPException(status_code=500, detail="Chat completion failed")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model": "qwen2.5-coder-14b",
        "model_loaded": qwen_api.model is not None,
        "device": qwen_api.device,
        "cache_size": len(qwen_api.memory_cache)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "api_server_14b:app",
        host="0.0.0.0",
        port=8000,
        workers=1,
        log_level="info"
    )