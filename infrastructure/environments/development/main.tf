locals {
  apps_path = "${path.module}/../../../apps"
}

module "development" {
  k8s_base_path           = "${path.module}/../../modules/kubernetes"
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
  argo_workflows_version  = "0.45.26"
  ingress_host            = "localhost"
  ingress_port            = 80

  # Applications
  # ------------
  # Preload base images for Argo Workflows
  base_images_to_load = [
    "python:3.11-alpine"
  ]

  storage_classes = {
    fast_storage = {
      name = "fast-storage"
      provisioner = "rancher.io/local-path"
      reclaim_policy = "Delete"
      volume_binding_mode = "Immediate"
    }
  }

  app_configs = {
    ingest_server = {
      metadata = {
        app_name        = "pixie-ingest"
        target_port     = 8080
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
        restart         = "Always" # Always (default), OnFailure, Never
        env_file        = ".env" # Path starting relatively from Dockerfile path
        # environment = {
        #   X=""
        #   Y=""
        # }
        depends_on      = []
        # NOTE: Probes are run from the container, not externally and thus not via ingress!!!
        # So we use INTERNAL port number and internal path.
        liveness_probe = {
          # Using an exec command similar to Docker Compose healthcheck 'test'
          command               = ["sh", "-c", "wget -q -O /dev/null http://localhost:${8000}/livez || exit 1"]
          # path                  = "/livez" # or we can use the path
          initial_delay_seconds = 60
          period_seconds        = 1200
          timeout_seconds       = 3
          failure_threshold     = 3
        }
        readiness_probe = {
          # Readiness continues to use the HTTP GET path
          path                  = "/readyz"
          initial_delay_seconds = 30
          period_seconds        = 300
          timeout_seconds       = 3 # Adding default timeout
          success_threshold     = 3
          failure_threshold     = 2
        }
      }
      /*
      # XOR (exclusive OR): use statefulset instead of deployment:
      statefulset = {
        replica_count   = 1
        has_probing     = false
        image_name      = "pixie-db"
        image_tag       = "1.0.0"
        docker_context  = local.apps_path
        dockerfile_path = "${local.apps_path}/ingest_server"
        request_cpu     = "128m"
        request_memory  = "128Mi"
        limit_cpu       = "256m"
        limit_memory    = "256Mi"
        restart         = "Always"
        env_file        = ".env" # Path starting relatively from Dockerfile path
        data_volumes = {
          pgdata = {
            name               = "pgdata"
            mount_path         = "/var/lib/app/data"
            storage_request    = "1Gi"
            storage_class_name = "fast-storage"
            access_mode        = "ReadWriteOnce"
          }
        }
      }
      */
      ingress = {
        path = "/ingest"
      }
    }
  }
}
