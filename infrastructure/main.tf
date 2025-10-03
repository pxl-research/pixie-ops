locals {
  app_name = "pixie-ingest"
}

# 1. Apply Deployment Manifest
# We use templatefile to render the deployment.yaml, injecting local and variable values.
resource "kubernetes_manifest" "app_deployment" {
  # yamldecode converts the rendered YAML string into a Terraform map structure.
  manifest = yamldecode(
    templatefile("${path.module}/../kubernetes/deployment.yaml", {
      app_name    = local.app_name
      image_name  = var.image_name
      image_tag   = var.image_tag
    })
  )
}

# 2. Apply Service Manifest
# We use templatefile to render the service.yaml, injecting the application name.
resource "kubernetes_manifest" "app_service" {
  manifest = yamldecode(
    templatefile("${path.module}/../kubernetes/service.yaml", {
      app_name = local.app_name
    })
  )

  # Ensure the service is created only after the deployment is fully available.
  depends_on = [kubernetes_manifest.app_deployment]
}
