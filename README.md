# TODO: write decent readme
## Installation
* Docker
* minikube
* kubectl
* OpenTofu


./minikube_setup.sh
cd infrastructure
tofu init
tofu plan
tofu apply -auto-approve
minikube service pixie-ingest-svc --url
curl -X POST http://127.0.0.1:40075/trigger

(maybe enforce somewhere a strict URL? because the port number changes each time)
