locals {
  # Naming
  cluster_name = "pixie"
  project_namespace_name = "pixie"
  argo_namespace_name = "argo"
  is_local_deployment = true

  # General paths
  apps_path = "${path.module}/../../../apps"
  k8s_base_path = "${path.module}/../../../kubernetes"

  # Ingress
  ingress_version = "4.7.1"
  ingress_host = "localhost"
  ingress_namespace_name = "ingress-nginx"

  # Packages
  argo_workflows_version = "0.45.26" # this is 3.7.2 outside of helm

  # List of base images to pre-load for Argo Workflows
  base_images_to_load = [
    "python:3.11-alpine",
  ]

  # Application Configuration Map (The structure for dynamic deployment)
  app_configs = {
    # Key 'ingest_server' is used as the resource instance identifier (e.g., docker_image.app["ingest_server"])
    ingest_server = {
      metadata = {
        app_name    = "pixie-ingest"
        target_port = 8000
      }
      deployment = {
        replica_count     = 1
        has_probing       = true
        image_name        = "pixie-ingest"
        image_tag         = "1.0.1"
        docker_context    = "${local.apps_path}"
        dockerfile_path   = "${local.apps_path}/ingest_server"
        request_cpu       = "128m"
        request_memory    = "256Mi"
        limit_cpu         = "256m"
        limit_memory      = "1Gi"
      }
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = true
        path    = "/ingest"
      }
    }
  }
}
