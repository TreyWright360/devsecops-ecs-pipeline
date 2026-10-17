# ==========================================
# Stage 1: Build & Dependencies
# ==========================================
FROM python:3.11-slim-bullseye AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ==========================================
# Stage 2: Hardened Non-Root Runtime Image
# ==========================================
FROM python:3.11-slim-bullseye AS runtime

# CIS Benchmark: Create dedicated non-root user (UID 10001)
RUN groupadd -g 10001 appuser && \
    useradd -u 10001 -g appuser -s /bin/false -m -d /home/appuser appuser

WORKDIR /app

# Copy installed Python packages from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source code with non-root ownership
COPY --chown=appuser:appuser app/ /app/

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Drop all privileges
USER 10001:10001

EXPOSE 8000

# Container liveness probe for ECS task agent
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
