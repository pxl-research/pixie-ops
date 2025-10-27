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
  k8s_apps_path = "${path.module}/../../../kubernetes/apps"
  k8s_base_path = "${path.module}/../../../kubernetes/base"
  
  # Apps specific paths
  # Ingest server
  ingest_server_app_path = "${local.apps_path}/ingest_server"
  ingest_server_k8s_path = "${local.k8s_apps_path}/ingest_server"
  ingest_server_ingress_path = "/ingest"
  ingest_server_target_port = 8000
  ingest_server_replica_count = 1

  # Ingress
  ingress_version = "4.7.1"
  ingress_host = "localhost"
  ingress_namespace_name = "ingress-nginx"
  
  # Packages
  argo_workflows_version = "0.45.26" # this is 3.7.2 outside of helm
  #argo_workflows_service_name = "argo-workflows-server"
  #argo_workflows_port = 2746
  ## Always use Service DNS names, not IPs!
  #argo_workflows_server = "http://${local.argo_workflows_service_name}.${local.argo_namespace_name}.svc.cluster.local:${local.argo_workflows_port}"
}