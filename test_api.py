#!/usr/bin/env python3
# ~/qwen-api/test_api.py

import requests
import json
import time
import sys

# Configuration
API_BASE_URL = "https://your-domain.com/v1"
API_KEY = "your-api-key-here"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

def test_health():
    """Test API health endpoint"""
    print("🏥 Testing health endpoint...")
    try:
        response = requests.get(f"{API_BASE_URL.replace('/v1', '')}/health", timeout=10)
        if response.status_code == 200:
            print("✅ Health check passed")
            print(f"   Status: {response.json()}")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check error: {e}")
        return False

def test_generate():
    """Test text generation endpoint"""
    print("\n🤖 Testing text generation...")
    
    payload = {
        "prompt": "Write a Python function to calculate the factorial of a number using recursion.",
        "max_tokens": 1024,
        "temperature": 0.1
    }
    
    try:
        start_time = time.time()
        response = requests.post(f"{API_BASE_URL}/generate", 
                               headers=headers, 
                               json=payload,
                               timeout=60)
        end_time = time.time()
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Generation successful")
            print(f"   Response time: {end_time - start_time:.2f}s")
            print(f"   User ID: {result.get('user_id')}")
            print(f"   Cached: {result.get('cached', False)}")
            print("   Generated code:")
            print("-" * 50)
            print(result["response"])
            print("-" * 50)
            return True
        else:
            print(f"❌ Generation failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Generation error: {e}")
        return False

def test_chat_completions():
    """Test OpenAI-compatible chat endpoint"""
    print("\n💬 Testing chat completions...")
    
    payload = {
        "messages": [
            {"role": "user", "content": "Explain the concept of Docker containers in simple terms."}
        ],
        "max_tokens": 1024,
        "temperature": 0.1
    }
    
    try:
        start_time = time.time()
        response = requests.post(f"{API_BASE_URL}/chat/completions", 
                               headers=headers, 
                               json=payload,
                               timeout=60)
        end_time = time.time()
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Chat completion successful")
            print(f"   Response time: {end_time - start_time:.2f}s")
            print(f"   Model: {result.get('model')}")
            print("   Response:")
            print("-" * 50)
            print(result["choices"][0]["message"]["content"])
            print("-" * 50)
            return True
        else:
            print(f"❌ Chat completion failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Chat completion error: {e}")
        return False

def test_rate_limiting():
    """Test rate limiting"""
    print("\n⏱️  Testing rate limiting...")
    
    payload = {
        "prompt": "Hello, world!",
        "max_tokens": 50
    }
    
    success_count = 0
    rate_limited_count = 0
    
    for i in range(10):
        try:
            response = requests.post(f"{API_BASE_URL}/generate", 
                                   headers=headers, 
                                   json=payload,
                                   timeout=30)
            if response.status_code == 200:
                success_count += 1
            elif response.status_code == 429:
                rate_limited_count += 1
                print(f"   Request {i+1}: Rate limited")
            else:
                print(f"   Request {i+1}: Error {response.status_code}")
                
        except Exception as e:
            print(f"   Request {i+1}: Exception {e}")
        
        time.sleep(1)
    
    print(f"✅ Rate limiting test completed")
    print(f"   Successful requests: {success_count}")
    print(f"   Rate limited requests: {rate_limited_count}")
    return rate_limited_count > 0  # Rate limiting should kick in

def main():
    """Run all tests"""
    print("🚀 Starting API Tests")
    print("=" * 60)
    
    if len(sys.argv) > 1 and sys.argv[1] == "--quick":
        # Quick test - just health and one generation
        tests = [test_health, test_generate]
    else:
        # Full test suite
        tests = [test_health, test_generate, test_chat_completions, test_rate_limiting]
    
    results = []
    for test in tests:
        results.append(test())
    
    print("\n" + "=" * 60)
    print("📊 Test Results Summary")
    print("=" * 60)
    
    test_names = ["Health Check", "Text Generation", "Chat Completions", "Rate Limiting"]
    for i, result in enumerate(results):
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_names[i]:20s}: {status}")
    
    overall_success = all(results)
    print(f"\nOverall: {'✅ ALL TESTS PASSED' if overall_success else '❌ SOME TESTS FAILED'}")
    
    return 0 if overall_success else 1

if __name__ == "__main__":
    exit(main())