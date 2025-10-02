locals {
  app_name = "pixie-ingest"
  labels = {
    app = local.app_name
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name = local.app_name
    labels = local.labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.labels
    }
    template {
      metadata {
        labels = local.labels
      }
      spec {
        container {
          name = local.app_name
          image = "${var.image_name}:${var.image_tag}"
          image_pull_policy = "Never" # Do not pull from registry
          port {
            container_port = 8000
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds = 10
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 2
            period_seconds = 5
          }
          resources {
            requests = {
              cpu = "256m"
              memory = "512Mi"
            }
            limits = {
              cpu = "512m"
              memory = "1024Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "svc" {
  metadata {
    name = "${local.app_name}-svc"
    labels = local.labels
  }
  spec {
    selector = local.labels
    port {
      port = 80 # not the port of the application
      target_port = 8000
      protocol = "TCP"
    }
    type = "NodePort"
  }
}

# cd ./infrastructure
# tofu init
# tofu apply -auto-approve

# tofu destroy -auto-approve
# minikube stop