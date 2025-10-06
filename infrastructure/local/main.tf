locals {
  app_name = "pixie-ingest"
}

# 0. Execute minikube setup script
# This resource runs the local script to set up the minikube environment 
# (e.g., start minikube, build and load local images).
# NOTE: This script MUST be run manually once before the very first 'tofu init' 
# or 'tofu apply' to ensure the 'minikube' context exists for the Kubernetes provider 
# to load its initial configuration.
resource "null_resource" "setup_minikube" {
  # Add a dummy trigger that changes on every 'apply' attempt to ensure 
  # the script runs *before* the deployment, mitigating timing issues 
  # where the provider might check the cluster state before Minikube is ready.
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    # Assuming the script is in the current working directory relative to where 'tofu apply' is run.
    command = "sh ./minikube_setup.sh"
    # Execute only on creation/update of this resource.
    when    = create 
  }
}

# 1. Create the Kubernetes Namespace for the application
resource "kubernetes_manifest" "pixie_namespace" {
  # Ensure the Minikube setup runs before attempting to create resources.
  depends_on = [null_resource.setup_minikube]

  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "pixie"
    }
  }
}

# 2. Apply Deployment Manifest
# We use templatefile to render the deployment.yaml, injecting local and variable values.
resource "kubernetes_manifest" "app_deployment" {
  # Ensure the namespace exists before deploying the application resources.
  depends_on = [kubernetes_manifest.pixie_namespace]

  # yamldecode converts the rendered YAML string into a Terraform map structure.
  manifest = yamldecode(
    templatefile("${path.module}/../kubernetes/base/deployment.yaml", {
      app_name    = local.app_name
      image_name  = var.image_name
      image_tag   = var.image_tag
    })
  )
}

# 3. Apply Service Manifest
# We use templatefile to render the service.yaml, injecting the application name.
resource "kubernetes_manifest" "app_service" {
  
  manifest = yamldecode(
    templatefile("${path.module}/../kubernetes/base/service.yaml", {
      app_name = local.app_name
    })
  )

  # Ensure the service is created only after the deployment is available.
  depends_on = [kubernetes_manifest.app_deployment]
}
