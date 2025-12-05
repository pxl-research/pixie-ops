# TODO: write decent readme
This is an attempt to create a simple DevOps/MLOps framework to quickly deploy cloud native applications on Kubernetes.
Please ignore everything below currently!

## Installation on Ubuntu (native or WSL2 on Windows):
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
    TODO
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
TODO
```

* Azure CLI:
```
TODO
```


## Development: local deployment
```
cd infrastructure/
minikube start --driver=docker --gpus=all --memory=6144mb
export KUBE_CONTEXT=minikube
alias kubectl="minikube kubectl --"
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml
kubectl describe node minikube | grep nvidia.com/gpu

tofu destroy # if necessary, or when having an error
tofu init
tofu plan
tofu apply -var="deployment_target=local" -var="gpu_used=true" -auto-approve

# Testing:
curl -H "Host: localhost" http://$(minikube ip):31007/ingest; echo
curl -X POST -H "Host: localhost" http://$(minikube ip):31007/ingest/trigger; echo
curl -H "Host: localhost" http://$(minikube ip):31007/ingest/status/{workflow_id}; echo

# Turn off cluster or delete it:
minikube stop
minikube delete
```

## Production: Azure Deployment on AKS
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

## TODO list:
* Extra GPU deployment and statefulset options
* Figure out why embedding model does not give logs for bge-m3 but not the small model: probably not enough memory? => test on workstation
* Make disk, RAM and GPU usage configurable for (minikube) cluster instead of hardcoding.
* Test embedding model (for GPU support on minikube).
* Azure infrastructure + common API with local.
* Might want to support Shared Uploads: Use Deployment with single RWX PVC. All replicas share the same files.
* For cloud use LoadBalancer for Gateway instead of NodePort like on local!!!
* How can we pull from GHCR and provide a key for private repo's?
* (What about images of multiple containers? Seems fine because split in multiple images.)
* (Make environment variables overwrite what is in .env (in order to patch what is in pulled Docker image). Seems fine.)
* Healthcheck for StatefulSet based on: https://github.com/pxl-research/pixie-tabular-db/blob/main/infra/docker/docker-compose.dev.yml

Note: only use CI/CD to build containers when pushing to main.
Changing production should be done by manually applying Terraform/OpenTofu.
