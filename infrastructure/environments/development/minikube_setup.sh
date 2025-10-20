#!/bin/bash

# Define resources for minikube
CPUS=2
MEMORY=2048mb
DRIVER="docker"
RUNTIME="docker"

# Define ingress settings
HOSTNAME="local.dev.pixie-ingest.com"

# Check if the minikube host is in the 'Running' state.
# The 'minikube status' command returns 0 if running.
# We check the status output for "host: Running" for a more explicit confirmation.
echo "Checking Minikube status..."
if minikube status --format '{{.Host}}' | grep -q 'Running'; then
    echo "Minikube host is already running."
else
    echo "Minikube is not running or is stopped. Starting it now..."
    minikube start \
        --cpus ${CPUS} \
        --memory ${MEMORY} \
        --driver ${DRIVER} \
        --container-runtime ${RUNTIME} \
        --gpus all
fi

# Ensure the kubectl context is updated
echo "Updating kubectl context and ensuring ingress addon is enabled..."
minikube update-context
kubectl config current-context # make sure minikube is current context
minikube addons enable ingress

# Update /etc/hosts for local development
INGRESS_IP=$(minikube ip)

echo "Setting up /etc/hosts entry for ${HOSTNAME} at IP ${INGRESS_IP}..."

# Remove existing HOSTNAME entry from /etc/hosts
# The '\b' ensures we match the whole word/hostname.
sudo sed -i "/[[:space:]]\+$HOSTNAME\b/d" /etc/hosts

# Add the new IP and HOSTNAME entry
echo "${INGRESS_IP} ${HOSTNAME}" | sudo tee -a /etc/hosts

echo "Minikube setup complete. You can access your service via ${HOSTNAME}."