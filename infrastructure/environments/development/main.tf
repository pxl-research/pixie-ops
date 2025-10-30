locals {
  apps_path = "${path.module}/../../../apps"
}

module "development" {
  source = "../../modules/local"
  is_local_deployment     = true

  # Build argument
  # --------------
  cluster_create          = var.cluster_create

  # Main configuration
  # ------------------
  cluster_name            = "pixie"
  project_namespace_name  = "pixie"
  argo_namespace_name     = "argo"
  ingress_namespace_name  = "ingress-nginx"
  argo_workflows_version  = "0.45.26"
  ingress_version         = "4.7.1"
  ingress_host            = "localhost"
  #k8s_base_path           = "${path.module}/../../../kubernetes"

  # Applications
  # ------------
  # Preload base images for Argo Workflows
  base_images_to_load = [
    "python:3.11-alpine"
  ]
  app_configs = {
    ingest_server = {
      metadata = {
        app_name        = "pixie-ingest"
        target_port     = 8000
      }
      deployment = {
        replica_count   = 1
        has_probing     = true
        image_name      = "pixie-ingest"
        image_tag       = "1.0.1"
        docker_context  = local.apps_path
        dockerfile_path = "${local.apps_path}/ingest_server"
        request_cpu     = "128m"
        request_memory  = "128Mi"
        limit_cpu       = "256m"
        limit_memory    = "256Mi"
      }
      ingress = {
        enabled         = true
        path            = "/ingest"
      }
    }
  }
}
