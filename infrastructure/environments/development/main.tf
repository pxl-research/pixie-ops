########################################
# NAMESPACE CREATION
########################################
#resource "kubernetes_namespace" "pixie_namespace" {
#  metadata {
#    name = local.pixie_namespace_name
#  }
#
#  depends_on = [
#    kind_cluster.default
#  ]
#}

resource "kubectl_manifest" "pixie_namespace" {
  yaml_body = templatefile("${local.k8s_base_path}/namespace.yaml", {
    namespace_name          = local.pixie_namespace_name
  })

  depends_on = [
    kind_cluster.default
  ]
}


########################################
# HELM RELEASES
########################################
resource "helm_release" "argo_workflows" {
  name             = "argo-workflows"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = local.argo_workflows_version
  namespace        = local.argo_namespace_name
  create_namespace = true

  values = [file("${local.k8s_base_path}/argo-workflows-values.yaml")]

  depends_on = [
    kubectl_manifest.pixie_namespace
  ]
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = local.ingress_version
  namespace        = local.ingress_namespace_name
  create_namespace = true

  values = [file("${local.k8s_base_path}/ingress-nginx-values.yaml")]

  depends_on = [
    kubectl_manifest.pixie_namespace
  ]
}

########################################
# WAIT FOR INGRESS CONTROLLER
########################################
resource "null_resource" "wait_for_ingress_nginx" {
  triggers = {
    key = uuid()
  }

  provisioner "local-exec" {
    command = "echo 'Waiting for the nginx ingress controller...' && kubectl wait --namespace ${helm_release.ingress_nginx.namespace} --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s"
  }

  depends_on = [helm_release.ingress_nginx]
}
########################################
# RBAC CONFIGURATION
########################################
resource "kubectl_manifest" "hera_rbac" {
  for_each = {
    serviceaccount   = "${local.k8s_base_path}/hera-submitter-sa.yaml"
    clusterrole      = "${local.k8s_base_path}/hera-submitter-role.yaml"
    binding_hera     = "${local.k8s_base_path}/hera-submitter-binding.yaml"
    binding_default  = "${local.k8s_base_path}/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    helm_release.argo_workflows,
    null_resource.wait_for_ingress_nginx
  ]
}


########################################
# INGEST SERVER IMAGE BUILD + LOAD
########################################

# Build the local Docker image
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

# Load the image into Kind
resource "null_resource" "kind_image_load_ingest_server" {
  triggers = {
    image_id     = docker_image.ingest_server.image_id
    cluster_name = kind_cluster.default.name
  }

  provisioner "local-exec" {
    command = "kind load docker-image ${docker_image.ingest_server.name} --name ${kind_cluster.default.name}"
  }

  depends_on = [
    docker_image.ingest_server,
    kind_cluster.default
  ]
}

# Rollout trigger (to redeploy on image rebuild)
resource "null_resource" "rollout_trigger" {
  triggers = {
    timestamp = timestamp()
  }

  depends_on = [null_resource.kind_image_load_ingest_server]
}

########################################
# INGEST SERVER DEPLOYMENT, SERVICE, INGRESS
########################################

resource "kubectl_manifest" "ingest_server_deployment" {

  yaml_body = templatefile("${local.ingest_server_k8s_path}/deployment.yaml", {
    app_name                = local.ingest_server_app_name
    namespace_name          = local.pixie_namespace_name
    image_name              = local.ingest_server_image_name
    image_tag               = local.ingest_server_image_tag
    rollout_trigger         = null_resource.rollout_trigger.triggers.timestamp
    is_local_deployment     = true
    image_pull_secret_name  = ""
    target_port             = local.ingest_server_target_port
    replica_count           = local.ingest_server_replica_count
  })

  wait = false

  depends_on = [
    null_resource.kind_image_load_ingest_server,
    null_resource.rollout_trigger
  ]
}

resource "kubectl_manifest" "ingest_server_service" {

  yaml_body = templatefile("${local.ingest_server_k8s_path}/service.yaml", {
    app_name       = local.ingest_server_app_name
    namespace_name = local.pixie_namespace_name
    is_local_deployment = true
    app_target_port = local.ingest_server_target_port
  })

  depends_on = [kubectl_manifest.ingest_server_deployment]
}

resource "kubectl_manifest" "ingest_server_ingress" {

  yaml_body = templatefile("${local.k8s_base_path}/ingress.yaml", {
    app_name       = local.ingest_server_app_name
    namespace_name = local.pixie_namespace_name
    ingress_host   = local.ingress_host
    ingress_path   = local.ingest_server_ingress_path 
  })

  depends_on = [
    kubectl_manifest.ingest_server_service,
    helm_release.ingress_nginx
  ]
}

########################################
# HERA BASE IMAGE LOAD
########################################

resource "null_resource" "kind_image_load_hera_echo_base_image" {
  triggers = {
    cluster_name = kind_cluster.default.name
  }

  provisioner "local-exec" {
    command = "kind load docker-image python:3.11-alpine --name ${kind_cluster.default.name}"
  }

  depends_on = [
    kubectl_manifest.ingest_server_ingress,
    kind_cluster.default
  ]
}