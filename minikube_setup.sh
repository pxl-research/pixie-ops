#!/bin/bash

# --- Minikube Setup and Docker Image Build Script ---

# 1. Start Minikube (if not already running)
echo "1. Ensuring Minikube is running..."
minikube status | grep 'host: Running'
if [ $? -ne 0 ]; then
    minikube start
fi

# Check if Minikube started successfully
if [ $? -ne 0 ]; then
    echo "ERROR: Minikube failed to start. Aborting build."
    exit 1
fi

# 2. Point Docker CLI to Minikube's Docker daemon
# This is crucial so the image is built directly into Minikube's internal registry,
# making it instantly available for Kubernetes deployments inside Minikube.
echo "2. Setting Docker environment to Minikube..."
eval $(minikube docker-env)

# 3. Automatically run the docker build command
IMAGE_NAME="fastapi-metaflow-image:latest"
echo "3. Building Docker image: $IMAGE_NAME..."
# The '.' assumes your Dockerfile is in the same directory as this script.
docker build --no-cache --pull -t "$IMAGE_NAME" .

BUILD_STATUS=$?

# 4. Reset Docker environment (optional but recommended for non-Minikube tasks)
echo "4. Resetting Docker environment back to host machine..."
eval $(minikube docker-env -u)

# 5. Final status check
if [ $BUILD_STATUS -eq 0 ]; then
    echo "SUCCESS: Image '$IMAGE_NAME' built successfully and available in Minikube."
else
    echo "FAILURE: Docker image build failed (Exit code: $BUILD_STATUS)."
fi

exit $BUILD_STATUS
