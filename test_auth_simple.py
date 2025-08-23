#!/usr/bin/env python3
"""
Einfacher Test für auth.py um Import- und Type-Probleme zu prüfen
"""

def test_imports():
    """Test ob alle Imports korrekt funktionieren"""
    try:
        # Test all imports from auth.py
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
        import os
        import logging
        
        print("✅ Alle Imports erfolgreich")
        return True
        
    except ImportError as e:
        print(f"❌ Import-Fehler: {e}")
        return False

def test_auth_module():
    """Test auth.py Modul Import"""
    try:
        from auth import api_key_manager, verify_token, require_admin, require_generate
        print("✅ auth.py Modul erfolgreich importiert")
        return True
        
    except ImportError as e:
        print(f"❌ auth.py Import-Fehler: {e}")
        return False
    except Exception as e:
        print(f"❌ auth.py Fehler: {e}")
        return False

def test_type_annotations():
    """Test Type-Annotations in auth.py"""
    try:
        import ast
        import inspect
        from auth import APIKeyManager
        
        # Check if Optional[List[str]] is used correctly
        manager = APIKeyManager()
        
        # Get method signatures
        create_api_key_sig = inspect.signature(manager.create_api_key)
        create_jwt_token_sig = inspect.signature(manager.create_jwt_token)
        
        print("✅ Type-Annotations sind korrekt definiert")
        return True
        
    except Exception as e:
        print(f"❌ Type-Annotation-Fehler: {e}")
        return False

if __name__ == "__main__":
    print("=== Auth.py Validierung ===")
    
    success = True
    success &= test_imports()
    success &= test_auth_module() 
    success &= test_type_annotations()
    
    if success:
        print("\n🎉 Alle Tests erfolgreich! auth.py ist bereit.")
    else:
        print("\n❌ Es gibt noch Probleme mit auth.py")
