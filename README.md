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

kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.7.2/install.yaml
kubectl patch deployment argo-server -n argo --type='json' \
-p='[
    {"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server", "--secure=false"]},
    {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}
]'

TODO: Terraform from here...

kubectl create serviceaccount hera-submitter -n argo
kubectl create clusterrolebinding argo-default-task-binding \
    --clusterrole=hera-submitter-role \
    --serviceaccount=argo:default

kubectl apply -n argo -f hera-binding.yaml
kubectl apply -n argo -f hera-submitter-role.yaml


# Not needed anymore, since done in Python code.
# export ARGO_TOKEN="Bearer $(kubectl create token hera-submitter -n argo)"

kubectl -n argo port-forward service/argo-server 2746:2746
kubectl -n argo port-forward svc/argo-workflows-server 2746:2746 via Terraform

python3 hello_world.py
kubectl get wf -n argo
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
curl -X POST $(minikube ip):30080/trigger
````