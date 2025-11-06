FROM python:3.13-slim

WORKDIR /app

# For liveness / readiness checks
RUN apt-get update && apt-get install -y --no-install-recommends curl wget \
    && rm -rf /var/lib/apt/lists/*

# Build arguments as environment variables in container
#ARG ARGO_WORKFLOWS_SERVER
#ENV ARGO_WORKFLOWS_SERVER=${ARGO_WORKFLOWS_SERVER}

# NOTE: Build context is not the current folder, but apps (previous folder)
COPY ingest_server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the current app and the shared base code
COPY ingest_server /app/
COPY shared /app/shared

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
