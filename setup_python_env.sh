#!/bin/bash
# Python Environment Setup für GPU_Server Projekt
# Behebt Pylance Import-Probleme durch korrekte Umgebungseinrichtung

set -e  # Exit on error

echo "🔧 GPU_Server Python Environment Setup"
echo "======================================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Warnung: Dieses Script ist für macOS optimiert"
fi

# Check Python installation
echo "📋 Python Installation prüfen..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python gefunden: $PYTHON_VERSION"
    PYTHON_PATH=$(which python3)
    echo "📍 Python Pfad: $PYTHON_PATH"
else
    echo "❌ Python3 nicht gefunden!"
    echo "Installiere Python 3.12+ von https://python.org"
    exit 1
fi

# Create virtual environment
echo ""
echo "🔧 Virtual Environment erstellen..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✅ Virtual Environment erstellt: ./venv/"
else
    echo "📁 Virtual Environment bereits vorhanden"
fi

# Activate virtual environment
echo ""
echo "🚀 Virtual Environment aktivieren..."
source venv/bin/activate

# Upgrade pip
echo ""
echo "⬆️  pip upgraden..."
pip install --upgrade pip

# Install requirements
echo ""
echo "📦 Dependencies installieren..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo "✅ Alle Dependencies installiert"
else
    echo "❌ requirements.txt nicht gefunden!"
    exit 1
fi

# Get venv Python path
VENV_PYTHON=$(which python)
echo ""
echo "🐍 Virtual Environment Python: $VENV_PYTHON"

# Create/update VSCode settings
echo ""
echo "⚙️  VSCode Konfiguration aktualisieren..."
mkdir -p .vscode

cat > .vscode/settings.json << EOF
{
  "python.defaultInterpreterPath": "$VENV_PYTHON",
  "python.pythonPath": "$VENV_PYTHON",
  "python.terminal.activateEnvironment": true,
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": false,
  "python.linting.flake8Enabled": true,
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoSearchPaths": true,
  "python.analysis.autoImportCompletions": true,
  "python.analysis.diagnosticMode": "workspace",
  "python.analysis.extraPaths": [
    "./venv/lib/python3.12/site-packages"
  ],
  "python.analysis.include": [
    "**/*.py"
  ],
  "python.analysis.exclude": [
    "**/venv",
    "**/.git",
    "**/node_modules",
    "**/__pycache__"
  ],
  "files.associations": {
    "requirements.txt": "pip-requirements"
  },
  "python.formatting.provider": "black",
  "python.linting.mypyEnabled": false,
  "python.terminal.executeInFileDir": false,
  "python.workspaceSymbols.enabled": true,
  "python.analysis.stubPath": "./venv/lib/python3.12/site-packages"
}
EOF

echo "✅ VSCode Konfiguration aktualisiert"

# Test imports
echo ""
echo "🧪 Import-Tests durchführen..."
python << 'EOF'
import sys
print(f"Python Version: {sys.version}")
print(f"Python Path: {sys.executable}")

# Test critical imports
try:
    import fastapi
    print("✅ FastAPI")
    import torch
    print("✅ PyTorch")
    import redis
    print("✅ Redis")
    import jwt
    print("✅ PyJWT")
    import transformers
    print("✅ Transformers")
    import pydantic
    print("✅ Pydantic")
    import uvicorn
    print("✅ Uvicorn")
    import slowapi
    print("✅ SlowAPI")
    import tenacity
    print("✅ Tenacity")
    import prometheus_client
    print("✅ Prometheus Client")
    
    print("\n🎉 Alle kritischen Imports erfolgreich!")
    
except ImportError as e:
    print(f"❌ Import-Fehler: {e}")
    sys.exit(1)
EOF

echo ""
echo "📋 Environment Informationen:"
echo "Virtual Environment: $(pwd)/venv"
echo "Python Executable: $VENV_PYTHON"
echo "pip Location: $(which pip)"

# Create activation reminder
echo ""
echo "📝 Verwendung:"
echo "1. Terminal: source venv/bin/activate"
echo "2. VSCode: Wähle Python Interpreter -> $VENV_PYTHON"
echo "3. Neustart von VSCode empfohlen für Pylance-Updates"

echo ""
echo "🎯 Setup abgeschlossen!"
echo "Starte VSCode neu um alle Änderungen zu übernehmen."
