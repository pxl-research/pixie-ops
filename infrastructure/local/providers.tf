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
  }
}

provider "kubernetes" {
  alias          = "minikube_conn"
  config_path    = "~/.kube/config" 
  config_context = "minikube" 
}

provider "helm" {
  alias = "minikube_conn"
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  alias          = "minikube_conn"
  config_path    = "~/.kube/config"
  config_context = "minikube"
}