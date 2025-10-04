# TODO: write decent readme
## Installation
* Docker
* minikube
* kubectl
* OpenTofu:
```
alias terraform=tofu
```
* MinIO (Replace /data with the path to the drive or directory in which you want MinIO to store data.):
```
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
./minio server /data
```

```
cd infrastructure
minikube start --cpus 2 --memory 2048mb --driver=docker
terraform init
terraform plan
terraform apply -auto-approve
curl -X POST $(minikube ip):30080/trigger
````