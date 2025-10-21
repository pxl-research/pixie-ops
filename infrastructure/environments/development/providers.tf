########################################
# LOCALS
########################################
locals {
  kube_config_path = pathexpand("~/.kube/config")
}

########################################
# TERRAFORM SETTINGS
########################################
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
      version = "3.6.2"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "0.9.0"
    }
  }
}

########################################
# KIND CLUSTER CREATION
########################################
resource "kind_cluster" "default" {
  name            = "kind"
  kubeconfig_path = local.kube_config_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      # Map ingress ports only
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
    }

    node {
      role = "worker"
    }
  }
}

########################################
# PROVIDERS
########################################

# Kubernetes provider (default)
provider "kubernetes" {
  host                   = kind_cluster.default.endpoint
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
}

# Helm provider (default)
provider "helm" {
  kubernetes = {
    host                   = kind_cluster.default.endpoint
    client_certificate     = kind_cluster.default.client_certificate
    client_key             = kind_cluster.default.client_key
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  }
}

# Kubectl provider
provider "kubectl" {
  config_path = local.kube_config_path
}

# Null provider
provider "null" {}

# Docker provider
provider "docker" {
  host = "unix:///var/run/docker.sock"
}
