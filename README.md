# TODO: write decent readme

./minikube_setup.sh
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
minikube service fastapi-metaflow-service --url
curl -X POST http://127.0.0.1:40075/trigger

(maybe enforce somewhere a strict URL? because the port number changes each time)
