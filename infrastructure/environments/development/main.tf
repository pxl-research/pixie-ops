resource "kubernetes_namespace" "argo_namespace" {
  metadata {
    name = local.argo_namespace_name
  }
}

resource "kubernetes_namespace" "pixie_namespace" {
  metadata {
    name = local.pixie_namespace_name
  }
}

resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = "${local.argo_workflows_version}"
  namespace  = kubernetes_namespace.argo_namespace.metadata.0.name
  values = [
    file("${local.k8s_base_path}/argo-workflows-values.yaml")
  ]
  depends_on = [
    kubernetes_namespace.argo_namespace
  ]
}

resource "kubectl_manifest" "hera_rbac" {
  for_each = {
    serviceaccount = "${local.k8s_base_path}/hera-submitter-sa.yaml"
    clusterrole    = "${local.k8s_base_path}/hera-submitter-role.yaml"
    binding_hera   = "${local.k8s_base_path}/hera-submitter-binding.yaml"
    binding_default = "${local.k8s_base_path}/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    helm_release.argo_workflows,
    kubernetes_namespace.argo_namespace
  ]
}

# ------------------------------------------------------------------------------
# App: Ingest Server
# ------------------------------------------------------------------------------

# Build Docker image locally
resource "docker_image" "ingest_server" {
  name = "${local.ingest_server_image_name}:${local.ingest_server_image_tag}"
  build {
    context    = local.apps_path
    dockerfile = "${local.ingest_server_app_path}/Dockerfile"
    build_args = {
      ARGO_WORKFLOWS_SERVER = local.argo_workflows_server
    }
  }
  depends_on = [kubectl_manifest.hera_rbac]
}

# Load image into Minikube
resource "null_resource" "minikube_image_load" {
  provisioner "local-exec" {
    command = "minikube image load ${docker_image.ingest_server.name}"
  }
  depends_on = [docker_image.ingest_server]
}

# Trigger-based null_resource to capture the time of the load
# This is a good proxy for an image change identifier
resource "null_resource" "rollout_trigger" {
  triggers = {
    # This value changes every time the minikube_image_load completes
    timestamp = timestamp()
  }
  depends_on = [null_resource.minikube_image_load]
}

# Deployment Manifest
resource "kubectl_manifest" "ingest_server_deployment" {
  yaml_body = templatefile("${local.ingest_server_k8s_path}/deployment.yaml", {
    app_name = local.ingest_server_app_name
    namespace_name = local.pixie_namespace_name
    image_name = local.ingest_server_image_name
    image_tag = local.ingest_server_image_tag
    rollout_trigger = null_resource.rollout_trigger.triggers.timestamp
    is_local_deployment = true
    image_pull_secret_name = "" # not used for local deployment, but needed for compilation
  })
  wait = false
  depends_on = [null_resource.minikube_image_load, null_resource.rollout_trigger]
}

# Service Manifest
resource "kubectl_manifest" "ingest_server_service" {
  yaml_body = templatefile("${local.ingest_server_k8s_path}/service.yaml", {
    app_name = local.ingest_server_app_name
    namespace_name = local.pixie_namespace_name
    is_local_deployment = true
  })
  depends_on = [kubectl_manifest.ingest_server_deployment]
}

# For Hera scripts:
resource "null_resource" "minikube_image_load_hera_echo_base_image" {
  provisioner "local-exec" {
    command = "minikube image load python:3.11-alpine"
  }
  depends_on = [kubectl_manifest.ingest_server_service]
}