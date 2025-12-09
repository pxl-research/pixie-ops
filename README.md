# pixie-ops
pixie-ops is a lightweight MLops/devops framework on top of Kubernetes & Terraform (OpenTofu) which simplifies cloud-native deployment to the same complexity level as Docker Compose. Ideal for demo's and proof-of-concepts in AI, machine learning pipelines and RAG. Works locally on minikube and on Azure cloud via push. Can pull images, but does not do CI/CD.
You have to push everything into production via tofu/terraform apply whenever you want for maximum control and to avoid complex CI/CD madness. \
In research, we like to keep it simple!&trade; \
<sub><sup>But we want to provide stakeholders a working Kubernetes cluster which can make transistion into production easier.</sup></sub>

## Feature list and restrictions
The following features have been ported over from Docker compose into our own framework:
* Currently only runs on-premise via minikube on Linux (Ubuntu/Debian) and WSL2 (Ubuntu/Debian) on Windows.
* TODO: list everything else

In order to simplify deployment significantly, the following restrictions and assumptions have been made:
* TODO: list everything

NOTE: Please ignore everything below currently!

## Installation on Ubuntu/Debian (native or WSL2 on Windows):
The following dependencies are needed:
* Docker:
```
sudo apt update && apt upgrade
sudo apt install -y ca-certificates curl gnupg wget

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

# Install Docker Engine and associated packages
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

sudo usermod -aG docker $USER

# exit current terminal and restart Ubuntu
exit

sudo systemctl enable docker
sudo systemctl start docker

# Optional: verify Docker installation
sudo docker run hello-world
```

* NVIDIA Container Toolkit:
```
# Add the GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Add the repository to your sources list
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure the container runtime for Docker and restart docker daemon
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify if GPU support works:
docker run --rm --gpus all nvidia/cuda:12.2.0-runtime-ubuntu22.04 nvidia-smi
```

* Minikube:
```
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

# Verify via:
minikube start --driver=docker --gpus=all --memory=2048mb
minikube delete
```

* kubectl
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

* Argo Workflows:
https://github.com/argoproj/argo-workflows/releases/
```
curl -sLO "https://github.com/argoproj/argo-workflows/releases/download/v3.7.2/argo-linux-amd64.gz" \
&& gunzip "argo-linux-amd64.gz" \
&& chmod +x "argo-linux-amd64" \
&& sudo mv "./argo-linux-amd64" /usr/local/bin/argo \
&& argo version
```

* OpenTofu:
```
# Download the installer script:
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh

# Give it execution permissions:
chmod +x install-opentofu.sh

# Run the installer:
./install-opentofu.sh --install-method deb

# Remove the installer:
rm -f install-opentofu.sh
```

* Azure CLI:
```
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

## Development: local deployment
```
cd infrastructure/
# If using WSL2 on Windows (mount to get access to CUDA drivers):
minikube start --driver=docker --container-runtime=docker --gpus=all --memory=4096mb --mount --mount-string="/usr/lib/wsl:/usr/lib/wsl"
# Or on Linux:
minikube start --driver=docker --container-runtime=docker --gpus=all --memory=8192mb

export KUBE_CONTEXT=minikube

# NOT necessary anymore: minikube addons enable nvidia-device-plugin
# NOT necessary anymore: alias kubectl="minikube kubectl --"
# NOT necessary anymore: kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.3/deployments/static/nvidia-device-plugin.yml

# Wait until this gives results:
kubectl describe node minikube | grep nvidia.com/gpu

 # if necessary, or when having an error
tofu destroy -auto-approve
minikube delete

tofu init
tofu plan
# If using WSL2 on Windows:
tofu apply -var="deployment_target=local_wsl2" -var="gpu_used=true" -var="profiles=['all']" -auto-approve
# Or on Linux (default):
tofu apply -var="deployment_target=local_linux" -var="gpu_used=true" -var="profiles=['all']" -auto-approve

# Testing:
curl -H "Host: localhost" http://$(minikube ip):31007/ingest; echo
curl -X POST -H "Host: localhost" http://$(minikube ip):31007/ingest/trigger; echo
curl -H "Host: localhost" http://$(minikube ip):31007/ingest/status/{workflow_id}; echo

# Turn off cluster or delete it:
minikube stop

tofu destroy -auto-approve
minikube delete
```

## Production: Azure Deployment on AKS
This is actively being worked on, so ignore the notes below!
```
cd infrastructure/environments/production
az login --use-device-code
tofu init
tofu plan
tofu apply -auto-approve

az aks get-credentials --resource-group pixie_k8s_rg --name pixie
kubectl config current-context

kubectl get svc -n argo
kubectl port-forward svc/argo-workflows-server 2746:2746 -n argo

curl http://$(kubectl get service pixie-ingest-svc --namespace pixie -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/; echo
curl -X POST http://$(kubectl get service pixie-ingest-svc --namespace pixie -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/trigger; echo
```

## TODO list (features):
* Azure infrastructure + common API with local.
* For cloud use LoadBalancer for Gateway instead of NodePort like on local!!!
* How can we pull from GHCR and provide a key for private repo's?
* Might want to support Shared Uploads: Use Deployment with single RWX PVC. All replicas share the same files.
* (Test if environment variables overwrite what is in .env (in order to patch what is in pulled Docker image). Seems fine.)
* Check if healthchecks can be simplified.
