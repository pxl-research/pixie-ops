terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "3.0.2"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config" 
  config_context = "minikube" 
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}