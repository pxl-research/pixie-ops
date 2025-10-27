locals {
  # Naming
  cluster_name = "pixie"
  argo_namespace_name = "argo"
  pixie_namespace_name = "pixie"
  ingest_server_app_name = "pixie-ingest"
  ingest_server_image_name = "pixie-ingest"
  ingest_server_image_tag = "1.0.0"
  
  # General paths
  apps_path = "${path.module}/../../../apps"
  k8s_base_path = "${path.module}/../../../kubernetes"
  
  # Ingress
  ingress_version = "4.7.1"
  ingress_host = "localhost"
  ingress_namespace_name = "ingress-nginx"
  
  # Packages
  argo_workflows_version = "0.45.26" # this is 3.7.2 outside of helm

  # Apps specific paths
  # TODO: make a more generic hashmap out of this
  # Ingest server
  ingest_server_app_path = "${local.apps_path}/ingest_server"
  ingest_server_ingress_path = "/ingest" # root path for this service
  ingest_server_target_port = 8000
  ingest_server_replica_count = 1
  ingest_server_has_probing = true
  ingest_server_request_cpu = "128m"
  ingest_server_request_memory = "256Mi"
  ingest_server_limit_cpu = "256m"
  ingest_server_limit_memory = "1Gi"
}