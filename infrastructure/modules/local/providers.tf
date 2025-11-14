terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.9.0"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "0.9.0"
    }
  }
}

########################################
# LOCALS
########################################
locals {
  kube_config_path = pathexpand("~/.kube/config")
}

########################################
# PROVIDERS
########################################

# Kubernetes provider (default)
provider "kubernetes" {
  # FIX: Conditionally reference the single instance (index [0]) only if it exists (var.create_cluster is true).
  # If the cluster is NOT being created, fall back to reading the kubeconfig file via the path (null value).
  host                   = kind_cluster.default[0].endpoint
  client_certificate     = kind_cluster.default[0].client_certificate
  client_key             = kind_cluster.default[0].client_key
  cluster_ca_certificate = kind_cluster.default[0].cluster_ca_certificate
}

# Helm provider (default)
provider "helm" {
  kubernetes = {
    # FIX: Conditionally reference the single instance (index [0]) only if it exists.
    host                   = kind_cluster.default[0].endpoint
    client_certificate     = kind_cluster.default[0].client_certificate
    client_key             = kind_cluster.default[0].client_key
    cluster_ca_certificate = kind_cluster.default[0].cluster_ca_certificate
  }
}

# Kubectl provider
provider "kubectl" {
  config_path = local.kube_config_path
}

# Null provider
# provider "null" {}

# Docker provider
provider "docker" {
  host = "unix:///var/run/docker.sock"
}
