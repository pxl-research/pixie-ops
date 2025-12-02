# Start from PyTorch official image
FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-runtime

# Set working directory
WORKDIR /app

# For liveness / readiness checks
RUN apt-get update && apt-get install -y --no-install-recommends curl wget \
    && rm -rf /var/lib/apt/lists/*

# NOTE: Build context is not the current folder, but apps (previous folder)
COPY embedding_model/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the current app and the shared base code if applicable
COPY embedding_model /app/

# Expose port
EXPOSE 8000

# Start FastAPI using uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
