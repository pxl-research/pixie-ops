locals {
  # Naming
  resource_group_name = "pixie-k8s-rg"
  aks_cluster_name    = "pixie"
  location            = "West Europe" # Choose your desired Azure region
  # Service Principal details for ACR/Image pulling (replace with actual values or data sources)
  # For simplicity, we'll assume the AKS managed identity will be used for ACR access.
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.47.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_pixie.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.cluster_ca_certificate)
}

provider "null" {
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks_pixie.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.aks_pixie.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_pixie.kube_config.0.cluster_ca_certificate)
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}