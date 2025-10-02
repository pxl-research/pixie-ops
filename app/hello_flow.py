# minikube start --cpus 4 --memory 4096mb --driver=docker
# 2. Tell your shell to use the Minikube Docker daemon.
# This ensures that when you run 'docker build', the image is stored directly
# inside the Minikube environment, making it available to Kubernetes.
# eval $(minikube docker-env)
from metaflow import FlowSpec, step, trigger

class HelloFlow(FlowSpec):
    """
    A simple flow that runs on Kubernetes.
    """
    @step
    def start(self):
        print("Starting the flow.")
        self.next(self.hello)

    @step
    def hello(self):
        print("Hello, Metaflow on Kubernetes!")
        self.message = "Hello from Metaflow!"
        self.next(self.end)

    @step
    def end(self):
        print(f"Flow finished. Message: {self.message}")

if __name__ == '__main__':
    HelloFlow()