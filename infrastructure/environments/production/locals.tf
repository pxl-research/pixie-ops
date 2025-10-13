locals {
  # Naming
  argo_namespace_name      = "argo"
  pixie_namespace_name     = "pixie"
  ingest_server_app_name   = "pixie-ingest"
  ingest_server_image_name = "pixie-ingest"
  ingest_server_image_tag  = "1.0.0"

  # Azure Naming
  resource_group_name = "pixie_k8s_rg"
  aks_cluster_name    = "pixie"
  acr_name            = "pxlpixieacr"
  location            = "West Europe"
  # TODO:
  # Service Principal details for ACR/Image pulling (replace with actual values or data sources)
  # For simplicity, we'll assume the AKS managed identity will be used for ACR access.

  ghcr_image_prefix = "ghcr.io/<OWNER>/<REPO>" # TODO: fill in correctly

  # General paths
  apps_path       = "${path.module}/../../../apps"
  k8s_apps_path   = "${path.module}/../../../kubernetes/apps"
  k8s_base_path   = "${path.module}/../../../kubernetes/base"

  # Apps specific paths
  ingest_server_app_path = "${local.apps_path}/ingest_server"
  ingest_server_k8s_path = "${local.k8s_apps_path}/ingest_server"

  # Packages
  argo_workflows_version = "0.45.26" # this is 3.7.2 outside of helm
}
