
resource "kubectl_manifest" "pixie_namespace" {
  yaml_body = templatefile("${local.k8s_base_path}/namespace.yaml", {
    namespace_name        = local.pixie_namespace_name
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
    command = "echo 'Waiting for the nginx ingress controller...' && kubectl wait --namespace ${helm_release.ingress_nginx.namespace} --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=600s"
  }

  depends_on = [helm_release.ingress_nginx]
}
########################################
# RBAC CONFIGURATION
########################################
resource "kubectl_manifest" "hera_rbac" {
  for_each = {
    serviceaccount  = "${local.k8s_base_path}/hera-submitter-sa.yaml"
    clusterrole     = "${local.k8s_base_path}/hera-submitter-role.yaml"
    binding_hera    = "${local.k8s_base_path}/hera-submitter-binding.yaml"
    binding_default = "${local.k8s_base_path}/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    helm_release.argo_workflows,
    null_resource.wait_for_ingress_nginx
  ]
}


########################################
# DYNAMIC APP DEPLOYMENT (IMAGE BUILD, LOAD, K8S MANIFESTS)
########################################

# 1. Build the local Docker image for each app using for_each
resource "docker_image" "app" {
  for_each = local.app_configs
  name = "${each.value.deployment.image_name}:${each.value.deployment.image_tag}"
  build {
    context    = "${each.value.deployment.context}"
    dockerfile = "${each.value.deployment.docker_build_path}/Dockerfile"
  }
  depends_on = [kubectl_manifest.hera_rbac]
}

# 2. Load the image into Kind for each app using for_each
resource "null_resource" "kind_image_load_app" {
  for_each = local.app_configs
  triggers = {
    image_id     = docker_image.app[each.key].image_id
    cluster_name = kind_cluster.default.name
  }
  provisioner "local-exec" {
    command = "kind load docker-image ${docker_image.app[each.key].name} --name ${kind_cluster.default.name}"
  }
  depends_on = [
    docker_image.app,
    kind_cluster.default
  ]
}

# 3. Rollout trigger (to redeploy on image rebuild) for each app using for_each
resource "null_resource" "rollout_trigger" {
  for_each = local.app_configs

  triggers = {
    timestamp = timestamp()
  }
  depends_on = [null_resource.kind_image_load_app]
}

# 4. Create Kubernetes Deployment for each app using for_each
resource "kubectl_manifest" "app_deployment" {
  for_each = local.app_configs

  yaml_body = templatefile("${local.k8s_base_path}/deployment.yaml", {
    app_name            = each.value.metadata.app_name
    namespace_name      = local.pixie_namespace_name
    is_local_deployment = local.is_local_deployment
    target_port         = each.value.metadata.target_port
    image_name          = each.value.deployment.image_name
    image_tag           = each.value.deployment.image_tag
    rollout_trigger     = null_resource.rollout_trigger[each.key].triggers.timestamp
    image_pull_secret_name = ""
    replica_count       = each.value.deployment.replica_count
    has_probing         = each.value.deployment.has_probing
    request_cpu         = each.value.deployment.request_cpu
    request_memory      = each.value.deployment.request_memory
    limit_cpu           = each.value.deployment.limit_cpu
    limit_memory        = each.value.deployment.limit_memory
  })

  wait = false

  depends_on = [
    null_resource.kind_image_load_app,
    null_resource.rollout_trigger
  ]
}

# 5. Create Kubernetes Service for each app using for_each
resource "kubectl_manifest" "app_service" {
  for_each = local.app_configs
  yaml_body = templatefile("${local.k8s_base_path}/service.yaml", {
    app_name          = each.value.metadata.app_name
    namespace_name    = local.pixie_namespace_name
    is_local_deployment = local.is_local_deployment
    target_port       = each.value.metadata.target_port
  })
  depends_on = [kubectl_manifest.app_deployment]
}

# 6. Create Kubernetes Ingress for each app that has ingress enabled
resource "kubectl_manifest" "app_ingress" {
  # Filter the map to only include apps where ingress is enabled
  for_each = {
    for k, v in local.app_configs : k => v
    if v.ingress.enabled
  }

  yaml_body = templatefile("${local.k8s_base_path}/ingress.yaml", {
    app_name          = each.value.metadata.app_name
    namespace_name    = local.pixie_namespace_name
    ingress_host      = local.ingress_host
    ingress_path      = each.value.ingress.path
  })

  depends_on = [
    kubectl_manifest.app_service,
    helm_release.ingress_nginx
  ]
}

########################################
# HERA BASE IMAGE LOAD
########################################
resource "null_resource" "kind_image_load_base_images" {
  for_each = toset(local.base_images_to_load) # ensure images are unique

  triggers = {
    # The key (which is the image name itself) is used as a trigger
    image_name   = each.key
    cluster_name = kind_cluster.default.name
  }
  provisioner "local-exec" {
    command = "kind load docker-image ${each.value} --name ${kind_cluster.default.name}"
  }

  depends_on = [
    kubectl_manifest.app_ingress,
    kind_cluster.default
  ]
}
