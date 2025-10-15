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

  # GHCR
  # Updated to use GHCR format (ghcr.io/<owner>/<repo>/<image>:<tag>)
  # Assuming the owner/repo are stored in local.ghcr_image_prefix.
  ghcr_registry_server = "ghcr.io"
  ghcr_username = "tomquaremepxl" 
  ghcr_image_prefix = "${local.ghcr_registry_server}/${local.ghcr_username}"
  ingest_server_full_image_name = "${local.ghcr_image_prefix}/${local.ingest_server_image_name}"

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
