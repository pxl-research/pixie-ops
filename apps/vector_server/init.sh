#!/bin/sh

echo "Starting Qdrant..."
./qdrant &

# Wait for Qdrant
sleep 5

echo "Creating collection in Qdrant..."

curl -X PUT "http://localhost:6333/collections/${QDRANT_COLLECTION}" \
  -H "Content-Type: application/json" \
  -d "{
    \"vectors\": {
      \"size\": ${VECTOR_SIZE},
      \"distance\": \"Cosine\"
    }
  }"

wait
