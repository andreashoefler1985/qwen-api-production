#!/usr/bin/env python3
"""
Sicherer Token-Generator für ai.hoefler-cloud.com
Generiert kryptographisch sichere Tokens und API-Keys
"""

import secrets
import hashlib
import base64
import os
import string
from datetime import datetime

class SecureTokenGenerator:
    def __init__(self):
        self.timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
    def generate_jwt_secret(self, length=64):
        """Generiert sicheren JWT Secret (256-bit)"""
        return secrets.token_hex(length)
    
    def generate_redis_password(self, length=32):
        """Generiert sicheres Redis-Passwort"""
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    def generate_api_key(self, prefix="ak"):
        """Generiert sicheren API-Key mit Prefix"""
        # 32 Bytes = 256-bit Entropie
        raw_key = secrets.token_bytes(32)
        # Base64 encoding für bessere Handhabung
        encoded_key = base64.urlsafe_b64encode(raw_key).decode('ascii').rstrip('=')
        return f"{prefix}_{encoded_key}"
    
    def generate_admin_api_key(self):
        """Generiert Admin API-Key mit spezieller Kennzeichnung"""
        return self.generate_api_key(prefix="ak_admin")
    
    def generate_csrf_token(self, length=32):
        """Generiert CSRF-Token"""
        return secrets.token_urlsafe(length)
    
    def generate_encryption_key(self, length=32):
        """Generiert Verschlüsselungsschlüssel"""
        return base64.urlsafe_b64encode(secrets.token_bytes(length)).decode('ascii')
    
    def hash_token(self, token):
        """Erstellt SHA-256 Hash eines Tokens"""
        return hashlib.sha256(token.encode()).hexdigest()
    
    def update_env_file(self, env_path='.env.production'):
        """Aktualisiert Environment-Datei mit neuen sicheren Tokens"""
        
        # Neue sichere Tokens generieren
        jwt_secret = self.generate_jwt_secret()
        redis_password = self.generate_redis_password()
        csrf_token = self.generate_csrf_token()
        encryption_key = self.generate_encryption_key()
        
        print("🔐 Generiere sichere Tokens...")
        print(f"   JWT Secret: {jwt_secret[:16]}... (64 Zeichen)")
        print(f"   Redis Password: {redis_password[:8]}... (32 Zeichen)")
        print(f"   CSRF Token: {csrf_token[:16]}... ({len(csrf_token)} Zeichen)")
        print(f"   Encryption Key: {encryption_key[:16]}... ({len(encryption_key)} Zeichen)")
        
        # Environment-Datei lesen
        if not os.path.exists(env_path):
            print(f"❌ {env_path} nicht gefunden!")
            return False
        
        with open(env_path, 'r') as f:
            content = f.read()
        
        # Backup erstellen
        backup_path = f"{env_path}.backup_{self.timestamp}"
        with open(backup_path, 'w') as f:
            f.write(content)
        print(f"💾 Backup erstellt: {backup_path}")
        
        # Tokens ersetzen
        replacements = {
            'JWT_SECRET=your-super-secure-jwt-secret-key-here-change-this': f'JWT_SECRET={jwt_secret}',
            'REDIS_PASSWORD=your-secure-redis-password-change-this': f'REDIS_PASSWORD={redis_password}',
            'JWT_SECRET=': f'JWT_SECRET={jwt_secret}',
            'REDIS_PASSWORD=': f'REDIS_PASSWORD={redis_password}'
        }
        
        # Neue Environment-Variablen hinzufügen
        new_vars = f"""
# Sichere Tokens (generiert am {datetime.now().strftime('%Y-%m-%d %H:%M:%S')})
CSRF_SECRET={csrf_token}
ENCRYPTION_KEY={encryption_key}
SESSION_SECRET={self.generate_jwt_secret(32)}
API_KEY_SALT={self.generate_jwt_secret(16)}
"""
        
        # Ersetzungen durchführen
        updated_content = content
        for old, new in replacements.items():
            if old in updated_content:
                updated_content = updated_content.replace(old, new)
                print(f"✅ Aktualisiert: {old.split('=')[0]}")
        
        # Neue Variablen anhängen falls nicht vorhanden
        if 'CSRF_SECRET=' not in updated_content:
            updated_content += new_vars
            print("✅ Neue Sicherheits-Variablen hinzugefügt")
        
        # Aktualisierte Datei schreiben
        with open(env_path, 'w') as f:
            f.write(updated_content)
        
        print(f"✅ {env_path} aktualisiert")
        return True
    
    def generate_api_key_set(self, user_id="admin", count=3):
        """Generiert Set von API-Keys für verschiedene Zwecke"""
        keys = {
            'admin': self.generate_admin_api_key(),
            'api': self.generate_api_key("ak_api"),
            'read_only': self.generate_api_key("ak_ro")
        }
        
        # Keys-Datei erstellen
        keys_file = f"api_keys_{self.timestamp}.txt"
        with open(keys_file, 'w') as f:
            f.write(f"# API-Keys für ai.hoefler-cloud.com\n")
            f.write(f"# Generiert am: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# Benutz-ID: {user_id}\n\n")
            
            for key_type, key_value in keys.items():
                f.write(f"{key_type.upper()}_API_KEY={key_value}\n")
                f.write(f"{key_type.upper()}_API_KEY_HASH={self.hash_token(key_value)}\n\n")
            
            f.write(f"# WICHTIG:\n")
            f.write(f"# - Sichere diese Keys an einem sicheren Ort\n")
            f.write(f"# - Lösche diese Datei nach dem Kopieren\n")
            f.write(f"# - Admin-Key hat volle Berechtigung\n")
            f.write(f"# - API-Key für normale API-Calls\n")
            f.write(f"# - Read-Only-Key nur für Lesezugriffe\n")
        
        print(f"🔑 API-Keys generiert und gespeichert in: {keys_file}")
        return keys, keys_file
    
    def validate_token_strength(self, token):
        """Validiert die Stärke eines Tokens"""
        if len(token) < 32:
            return False, "Token zu kurz (minimum 32 Zeichen)"
        
        # Entropie-Check (vereinfacht)
        charset_size = len(set(token))
        if charset_size < 16:
            return False, "Token hat zu wenig verschiedene Zeichen"
        
        return True, "Token ist sicher"

def main():
    print("🔐 Sicherer Token-Generator für ai.hoefler-cloud.com")
    print("=" * 60)
    
    generator = SecureTokenGenerator()
    
    # 1. Environment-Datei aktualisieren
    print("\n1. Aktualisiere Environment-Variablen...")
    if generator.update_env_file():
        print("✅ Environment-Datei erfolgreich aktualisiert")
    else:
        print("❌ Fehler beim Aktualisieren der Environment-Datei")
        return
    
    # 2. API-Keys generieren
    print("\n2. Generiere API-Keys...")
    keys, keys_file = generator.generate_api_key_set()
    
    # 3. Zusammenfassung
    print("\n" + "=" * 60)
    print("✅ TOKEN-GENERIERUNG ABGESCHLOSSEN")
    print("=" * 60)
    print(f"📁 Environment-Backup: .env.production.backup_{generator.timestamp}")
    print(f"🔑 API-Keys Datei: {keys_file}")
    print(f"📊 Generierte Keys: {len(keys)}")
    
    print("\n⚠️  WICHTIGE SICHERHEITSHINWEISE:")
    print("   1. API-Keys aus der generierten Datei kopieren")
    print("   2. Keys-Datei nach dem Kopieren LÖSCHEN")
    print("   3. Environment-Backup sicher aufbewahren")
    print("   4. Keine Keys in Git committen")
    print("   5. Keys regelmäßig rotieren")
    
    print("\n🚀 Bereit für Produktions-Deployment!")

if __name__ == "__main__":
    main()
