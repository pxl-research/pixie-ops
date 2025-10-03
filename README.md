# TODO: write decent readme
## Installation
* Docker
* minikube
* kubectl
* OpenTofu:
```
alias terraform=tofu
```

```
cd infrastructure
minikube start
terraform init
terraform plan
terraform apply -auto-appro
curl -X POST $(minikube ip):30080/trigger
```