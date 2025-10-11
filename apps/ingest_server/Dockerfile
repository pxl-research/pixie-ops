FROM python:3.13-slim

WORKDIR /app

# NOTE: Build context is not the current folder, but apps (previous folder)

COPY ingest_server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the current app and the shared base code
COPY ingest_server /app/
COPY shared /app/shared

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]