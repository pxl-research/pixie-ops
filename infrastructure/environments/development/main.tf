resource "kubectl_manifest" "project_namespace" {
  # Only create this resource when the cluster is NOT being created in this run.
  count = var.create_cluster ? 0 : 1

  yaml_body = templatefile("${local.k8s_base_path}/namespace.yaml", {
    namespace_name = local.project_namespace_name
  })

  depends_on = [
    kind_cluster.default # Dependency remains, but is satisfied or skipped based on count
  ]
}

########################################
# HELM RELEASES
########################################
resource "helm_release" "argo_workflows" {
  count = var.create_cluster ? 0 : 1

  name             = "argo-workflows"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = local.argo_workflows_version
  namespace        = local.argo_namespace_name
  create_namespace = true

  values = [file("${local.k8s_base_path}/argo-workflows-values.yaml")]

  depends_on = [
    # Reference the singular instance [0]
    kubectl_manifest.project_namespace[0]
  ]
}

resource "helm_release" "ingress_nginx" {
  count = var.create_cluster ? 0 : 1

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = local.ingress_version
  namespace        = local.ingress_namespace_name
  create_namespace = true

  values = [file("${local.k8s_base_path}/ingress-nginx-values.yaml")]

  depends_on = [
    # Reference the singular instance [0]
    kubectl_manifest.project_namespace[0]
  ]
}

########################################
# WAIT FOR INGRESS CONTROLLER
########################################
resource "null_resource" "wait_for_ingress_nginx" {
  count = var.create_cluster ? 0 : 1

  triggers = {
    key = uuid()
  }

  provisioner "local-exec" {
    # Reference the singular instance [0]
    command = "echo 'Waiting for the nginx ingress controller...' && kubectl wait --namespace ${helm_release.ingress_nginx[0].namespace} --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=600s"
  }

  # Reference the singular instance [0]
  depends_on = [helm_release.ingress_nginx[0]]
}
########################################
# RBAC CONFIGURATION
########################################
resource "kubectl_manifest" "hera_rbac" {
  # Use conditional map: empty map if true, static map if false
  for_each = var.create_cluster ? {} : {
    serviceaccount  = "${local.k8s_base_path}/hera-submitter-sa.yaml"
    clusterrole     = "${local.k8s_base_path}/hera-submitter-role.yaml"
    binding_hera    = "${local.k8s_base_path}/hera-submitter-binding.yaml"
    binding_default = "${local.k8s_base_path}/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    # Reference the singular instances [0]
    helm_release.argo_workflows[0],
    null_resource.wait_for_ingress_nginx[0]
  ]
}


########################################
# DYNAMIC APP DEPLOYMENT (IMAGE BUILD, LOAD, K8S MANIFESTS)
########################################

# 1. Build the local Docker image for each app using for_each
resource "docker_image" "app" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.create_cluster ? {} : local.app_configs

  name = "${each.value.deployment.image_name}:${each.value.deployment.image_tag}"
  build {
    context    = "${each.value.deployment.docker_context}"
    dockerfile = "${each.value.deployment.dockerfile_path}/Dockerfile"
  }
  depends_on = [
    kubectl_manifest.hera_rbac # Already a for_each resource, no [0] needed
  ]
}

# 2. Load the image into Kind for each app using for_each
resource "null_resource" "kind_image_load_app" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.create_cluster ? {} : local.app_configs

  triggers = {
    image_id     = docker_image.app[each.key].image_id
    cluster_name = local.cluster_name
  }
  provisioner "local-exec" {
    command = "kind load docker-image ${docker_image.app[each.key].name} --name ${local.cluster_name}"
  }

  depends_on = [
    kind_cluster.default,
    docker_image.app,
  ]
}

# 3. Rollout trigger (to redeploy on image rebuild) for each app using for_each
resource "null_resource" "rollout_trigger" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.create_cluster ? {} : local.app_configs

  triggers = {
    timestamp = timestamp()
  }
  depends_on = [null_resource.kind_image_load_app]
}

# 4a. Create Kubernetes Deployment for each app using for_each
resource "kubectl_manifest" "app_deployment" {
  # Filter the map to only include apps that have a deployment config AND create_cluster is false
  for_each = {
      for k, v in local.app_configs : k => v
      if !var.create_cluster && try(v.deployment, null) != null
    }

  yaml_body = templatefile("${local.k8s_base_path}/deployment.yaml", {
    app_name            = each.value.metadata.app_name
    namespace_name      = local.project_namespace_name
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

// TODO: # 4b. Create Kubernetes StatefulSet for each app using for_each

# 5. Create Kubernetes Service for each app using for_each
resource "kubectl_manifest" "app_service" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.create_cluster ? {} : local.app_configs

  yaml_body = templatefile("${local.k8s_base_path}/service.yaml", {
    app_name          = each.value.metadata.app_name
    namespace_name    = local.project_namespace_name
    is_local_deployment = local.is_local_deployment
    target_port       = each.value.metadata.target_port
  })
  depends_on = [kubectl_manifest.app_deployment]
}

# 6. Create Kubernetes Ingress for each app that has ingress enabled
resource "kubectl_manifest" "app_ingress" {
  # Filter the map to only include apps where ingress is enabled AND create_cluster is false
  for_each = {
    for k, v in local.app_configs : k => v
    if !var.create_cluster && v.ingress.enabled
  }

  yaml_body = templatefile("${local.k8s_base_path}/ingress.yaml", {
    app_name          = each.value.metadata.app_name
    namespace_name    = local.project_namespace_name
    ingress_host      = local.ingress_host
    ingress_path      = each.value.ingress.path
  })

  depends_on = [
    kubectl_manifest.app_service,
    # Reference the singular instance [0]
    helm_release.ingress_nginx[0]
  ]
}

########################################
# HERA BASE IMAGE LOAD
########################################
resource "null_resource" "kind_image_load_base_images" {
  # Use conditional set: empty set if true, set of images if false
  for_each = var.create_cluster ? toset([]) : toset(local.base_images_to_load) # ensure images are unique

  triggers = {
    image_name   = each.key
    cluster_name = local.cluster_name
  }
  provisioner "local-exec" {
    command = "kind load docker-image ${each.value} --name ${local.cluster_name}"
  }

  depends_on = [
    kubectl_manifest.app_ingress,
    kind_cluster.default
  ]
}
