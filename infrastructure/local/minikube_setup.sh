#!/bin/bash

IMAGE_NAME="pixie-ingest:latest"
BUILD_STATUS=1

cleanup() {
    echo "4. Resetting Docker environment back to host machine..."
    eval $(minikube docker-env -u)
}
trap cleanup EXIT

echo "1. Ensuring Minikube is running..."
if ! minikube status | grep -q 'host: Running'; then
    minikube start || { echo "ERROR: Minikube failed to start"; exit 1; }
fi

echo "2. Setting Docker environment to Minikube..."
eval $(minikube docker-env)

# Build context is the directory of the script itself
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT="$SCRIPT_DIR"   # absolute path

docker build --no-cache --pull -t "$IMAGE_NAME" "$BUILD_CONTEXT" --build-arg ARGO_TOKEN=$ARGO_TOKEN

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo "SUCCESS: Image '$IMAGE_NAME' built successfully and available in Minikube."
else
    echo "FAILURE: Docker image build failed (Exit code: $BUILD_STATUS)."
fi

exit $BUILD_STATUS
