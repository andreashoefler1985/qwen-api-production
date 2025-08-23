# ~/qwen-api/Dockerfile.14b
FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y \
    git curl wget \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -s /bin/bash qwen

WORKDIR /app

# Python dependencies für 14B Modell
COPY requirements.14b.txt .
RUN pip install --no-cache-dir -r requirements.14b.txt

# Application code
COPY --chown=qwen:qwen . .

# Switch to non-root user
USER qwen

EXPOSE 8000

CMD ["python", "api_server_14b.py"]