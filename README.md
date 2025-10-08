# TODO: write decent readme
## Installation
* Docker
* minikube
    * export KUBE_CONFIG_PATH="~/.kube/config"
* kubectl
* Argo:
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

```
cd infrastructure/local
minikube start --cpus 2 --memory 2048mb --driver=docker
tofu init
tofu plan
tofu apply -auto-approve
kubectl -n argo port-forward svc/argo-workflows-server 2746:2746
python3 hello_world.py
kubectl get wf -n argo

TODO: via FastAPI:
curl -X POST $(minikube ip):30080/trigger
````