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
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config" 
  config_context = "minikube" 
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}