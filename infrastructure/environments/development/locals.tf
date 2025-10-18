locals {
  # Naming
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
  ingest_server_app_path = "${local.apps_path}/ingest_server"
  ingest_server_k8s_path = "${local.k8s_apps_path}/ingest_server"
  
  # Packages
  argo_workflows_version = "0.45.26" # this is 3.7.2 outside of helm
  argo_workflows_server = "http://argo-workflows-server.argo.svc.cluster.local:2746"
}