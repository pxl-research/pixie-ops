locals {
  kube_config_path = "~/.kube/config"
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.4"
    }
    kubectl = {
      source = "alekc/kubectl"
      version = "2.1.3"
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
  config_path    = local.kube_config_path
  config_context = "minikube" 
}

provider "null" {
}

provider "helm" {
  kubernetes = {
    config_path = local.kube_config_path
  }
}

provider "kubectl" {
  config_path    = local.kube_config_path
  config_context = "minikube"
}

data "external" "docker_host_lookup" {
  program = ["bash", "-c", "docker context inspect --format '{\"host\":\"{{.Endpoints.docker.Host}}\"}'"]
}
provider "docker" {
  host = "unix:///var/run/docker.sock" # data.external.docker_host_lookup.result.host
}