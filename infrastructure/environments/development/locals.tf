locals {
  # Naming
  cluster_name = "pixie"
  argo_namespace_name = "argo"
  pixie_namespace_name = "pixie"
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

  # Apps specific paths
  # TODO: make a more generic hashmap out of this, dividing it in deployment/statefulset, service, ingress submaps
  # Ingest server
  # deployment, service, ingress
  ingest_server_app_name = "pixie-ingest"
  ingest_server_target_port = 8000
  # Docker (put this under deployment?)
  ingest_server_app_path = "${local.apps_path}/ingest_server" # Docker image
  # deployment.yaml or statefulset.yaml
  ingest_server_replica_count = 1
  ingest_server_has_probing = true
  ingest_server_image_name = "pixie-ingest"
  ingest_server_image_tag = "1.0.0"
  ingest_server_request_cpu = "128m"
  ingest_server_request_memory = "256Mi"
  ingest_server_limit_cpu = "256m"
  ingest_server_limit_memory = "1Gi"
  #ingest_server_request_storage = "10Gi" # only for statefulset.yaml
  # ingress.yaml
  ingest_server_ingress_path = "/ingest" # root path for this service

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
        docker_build_path = "${local.apps_path}/ingest_server"
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

  /*
  {
    "metadata": {
      "app_name": "pixie-ingest",
      "namespace_name": "pixie",
      "target_port": 8000, # container port
    }
    "deployment": { # or "statefulset"
      "replica_count": 1,
      "has_probing": true,
      "image_name": "pixie-ingest",
      "image_tag": "1.0.0",
      "docker_build_path": "${local.apps_path}/ingest_server",
      "request_cpu": "128m",
      "request_memory": "256Mi",
      "limit_cpu": "256m",
      "limit_memory": "1Gi",
      # "request_storage": "10Gi" # only for statefulset
    },
    "service": {
      "type": "ClusterIP"
    },
    "ingress": {
      "enabled": true,
      "path": "/ingest"
    }
}
  */
}
