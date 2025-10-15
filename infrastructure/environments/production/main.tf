# Azure Resource Group
resource "azurerm_resource_group" "pixie_k8s_rg" {
  name     = local.resource_group_name
  location = local.location
}

# Azure Kubernetes Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "pixie_aks" {
  name                = local.aks_cluster_name
  location            = azurerm_resource_group.pixie_k8s_rg.location
  resource_group_name = azurerm_resource_group.pixie_k8s_rg.name
  dns_prefix          = local.aks_cluster_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "LocalDev"
  }
}

# Ensure Kubernetes providers wait for the cluster kubeconfig to be ready
resource "time_sleep" "wait_for_aks_ready" {
  create_duration = "60s"
  depends_on      = [azurerm_kubernetes_cluster.pixie_aks]
}

resource "kubernetes_namespace" "argo_namespace" {
  metadata {
    name = local.argo_namespace_name
  }
  depends_on = [time_sleep.wait_for_aks_ready]
}

resource "kubernetes_namespace" "pixie_namespace" {
  metadata {
    name = local.pixie_namespace_name
  }
  depends_on = [time_sleep.wait_for_aks_ready]
}

resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = "${local.argo_workflows_version}"
  namespace  = kubernetes_namespace.argo_namespace.metadata.0.name
  values = [
    file("${local.k8s_base_path}/argo-workflows-values.yaml")
  ]
  depends_on = [
    kubernetes_namespace.argo_namespace
  ]
}

resource "kubectl_manifest" "hera_rbac" {
  for_each = {
    serviceaccount  = "${local.k8s_base_path}/hera-submitter-sa.yaml"
    clusterrole     = "${local.k8s_base_path}/hera-submitter-role.yaml"
    binding_hera    = "${local.k8s_base_path}/hera-submitter-binding.yaml"
    binding_default = "${local.k8s_base_path}/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    helm_release.argo_workflows,
    kubernetes_namespace.argo_namespace
  ]
}

# ------------------------------------------------------------------------------
# App: Ingest Server (Docker Build/Load steps are REMOVED)
# ------------------------------------------------------------------------------

# **Removed:** docker_image.ingest_server (Local build)
# **Removed:** null_resource.minikube_image_load (Local load)

# GHCR image full name:
locals {
  # Updated to use GHCR format (ghcr.io/<owner>/<repo>/<image>:<tag>)
  # Assuming the owner/repo are stored in local.ghcr_image_prefix.
  ingest_server_full_image_name = "${local.ghcr_image_prefix}/${local.ingest_server_image_name}:${local.ingest_server_image_tag}"

  # GHCR
  ghcr_registry_server = "ghcr.io"
  ghcr_username = "tomquaremepxl" 

  # The actual Docker config JSON structure
  docker_config_json = jsonencode({
    auths = {
      "${local.ghcr_registry_server}" = {
        username = local.ghcr_username 
        # 'GHCR_PAT' is the actual token
        password = var.ghcr_pat 
        # Base64 encoded 'USERNAME:PAT' string
        auth     = base64encode("${local.ghcr_username}:${var.ghcr_pat}")
      }
    }
  })
}

# Rollout trigger remains a good pattern for forcing redeployment on image change
resource "null_resource" "rollout_trigger" {
  triggers = {
    # In a real pipeline, this value would be set externally based on image push time/hash.
    timestamp = timestamp() 
  }
  depends_on = [kubectl_manifest.hera_rbac] # Depend on previous K8s resources
}

# Kubernetes Secret
resource "kubernetes_secret" "ghcr_pull_secret" {
  metadata {
    name      = "ghcr-imagepullsecret"
    namespace = kubernetes_namespace.pixie_namespace.metadata.0.name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    # The key for this type of secret must be exactly .dockerconfigjson
    ".dockerconfigjson" = local.docker_config_json
  }
  
  # Ensure the namespace is ready before creating the secret
  depends_on = [
    kubernetes_namespace.pixie_namespace 
  ]
}

# Deployment Manifest - Image name updated to use ACR full path
resource "kubectl_manifest" "ingest_server_deployment" {
  yaml_body = templatefile("${local.ingest_server_k8s_path}/deployment.yaml", {
    app_name        = local.ingest_server_app_name
    image_name      = local.ingest_server_full_image_name # <--- CHANGE
    image_tag       = "" # Tag is now part of the full image name
    rollout_trigger = null_resource.rollout_trigger.triggers.timestamp
    is_local_deployment = false 
    image_pull_secret_name = kubernetes_secret.ghcr_pull_secret.metadata.0.name 
  })
  wait = false
  depends_on = [
    null_resource.rollout_trigger,
    kubernetes_secret.ghcr_pull_secret 
    # azurerm_container_registry.pixie_acr # Ensure ACR exists before deploying manifests that reference it
  ]
}

# Service Manifest
resource "kubectl_manifest" "ingest_server_service" {
  yaml_body = templatefile("${local.ingest_server_k8s_path}/service.yaml", {
    app_name = local.ingest_server_app_name
  })
  depends_on = [kubectl_manifest.ingest_server_deployment]
}

# For Hera scripts:
# Minikube image load is replaced with a simple null_resource dependency
resource "null_resource" "hera_echo_base_image_dependency" {
  # This resource now only serves as a dependency anchor, 
  # assuming 'python:3.11-alpine' is available from Docker Hub or a configured repository.
  depends_on = [kubectl_manifest.ingest_server_service]
}



# TODO:
# 1) Create a GitHub Personal Access Token (PAT) with the read:packages scope.
# 2) Create a Kubernetes Secret of type kubernetes.io/dockerconfigjson in the relevant namespace (pixie).
# 3) Reference this secret in the Kubernetes Deployment's imagePullSecrets field.