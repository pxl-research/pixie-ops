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

* kind:
```
# Linux
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
# For M1 / ARM Macs
[ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-darwin-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

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

## Development: local deployment on minikube
```
cd infrastructure/environments/development
tofu destroy # if necessary, or when having an error
tofu init
tofu plan
tofu apply -var="cluster_create=true" -auto-approve # first only create the cluster
# wait +- 2 minutes
tofu apply -auto-approve # then create the resources on the cluster


# Only use this in another terminal if you want to inspect workflows via the browser (during development)
./port_forwarding.sh

curl http://localhost:8080/ingest; echo
curl -X POST http://localhost:8080/ingest/trigger; echo
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
* Fix: Make sure rebuilding works without having to change version number.
* Test embedding model (for GPU support).
* Might want to support Shared Uploads: Use Deployment with single RWX PVC. All replicas share the same files.
* For cloud use LoadBalancer for Gateway instead of NodePort like on local!!!
* How can we pull from GHCR and provide a key for private repo's?
* (What about images of multiple containers? Seems fine because split in multiple images.)
* (Make environment variables overwrite what is in .env (in order to patch what is in pulled Docker image). Seems fine.)
* Healthcheck for StatefulSet based on: https://github.com/pxl-research/pixie-tabular-db/blob/main/infra/docker/docker-compose.dev.yml

Note: only use CI/CD to build containers when pushing to main.
Changing production should be done by manually applying Terraform/OpenTofu.


```
+-------------------+
|   Client (User)   |
|       curl        |
+---------+---------+
          |
          v
+-------------------+
|   localhost:80    |
|   (hostPort:80)   |
+---------+---------+
          |
          v
+-------------------+
|  kind Node (VM)   |
| extraPortMapping  |
| 80 -> 31007       |
+---------+---------+
          |
          v
+---------------------------+
| NGINX Gateway Service     |
| Type: NodePort            |
| 31007 -> targetPort: 80   |
+-------------+-------------+
              |
              v
+---------------------------+
| NGINX Gateway API Fabric  |
| Controller Pod            |
| Applies Gateway + Routes  |
+-------------+-------------+
              |
              v
+---------------------------+
|   App Service (ClusterIP) |
|   name: ${app_name}-svc   |
|   port: 80 -> 8080        |
+-------------+-------------+
              |
              v
+---------------------------+
|  Backend Pod              |
|  ${app_name} container    |
|  running on :8080         |
+---------------------------+

```
