# TODO: write decent readme
## Installation
* Docker
* minikube
    * export KUBE_CONFIG_PATH="~/.kube/config"
    * ```
    TODO
    ```
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

* Azure CLI:
```
TODO
```

```
cd infrastructure/environments/development
minikube start --cpus 2 --memory 2048mb --driver=docker
tofu destroy # if necessary
tofu init
tofu plan
tofu apply -auto-approve
./port-forwarding.sh

# In other terminal:
curl http://$(minikube ip):30080/; echo
curl -X POST http://$(minikube ip):30080/trigger; echo
````
