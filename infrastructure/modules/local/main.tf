# Define default probe parameters based on the original configuration
locals {
  default_liveness_probe = {
    path                  = null
    command               = null
    initial_delay_seconds = 60    # from original config
    period_seconds        = 1200  # from original config
    timeout_seconds       = 3     # from original config
    failure_threshold     = 3     # from original config
    success_threshold     = 1     # default for Liveness
  }
  default_readiness_probe = {
    path                  = null
    command               = null
    initial_delay_seconds = 30    # from original config
    period_seconds        = 300   # from original config
    timeout_seconds       = 3     # from original config
    failure_threshold     = 2     # from original config
    success_threshold     = 3     # from original config
  }
}

resource "kind_cluster" "default" {
  count           = 1
  name            = var.cluster_name
  kubeconfig_path = local.kube_config_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      # Map ingress ports only
      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
    }

    node {
      role = "worker"
    }
  }
}

resource "kubectl_manifest" "project_namespace" {
  # Only create this resource when the cluster is NOT being created in this run.
  count = var.cluster_create ? 0 : 1

  yaml_body = templatefile("${var.k8s_base_path}/namespace.yaml", {
    namespace_name = var.project_namespace_name
  })

  depends_on = [
    kind_cluster.default # Dependency remains, but is satisfied or skipped based on count
  ]
}

########################################
# HELM RELEASES
########################################
resource "helm_release" "argo_workflows" {
  count = var.cluster_create ? 0 : 1

  name             = "argo-workflows"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = var.argo_workflows_version
  namespace        = var.argo_namespace_name
  create_namespace = true

  values = [file("${var.k8s_base_path}/argo-workflows-values.yaml")]

  depends_on = [
    # Reference the singular instance [0]
    kubectl_manifest.project_namespace[0]
  ]
}

resource "helm_release" "ingress_nginx" {
  count = var.cluster_create ? 0 : 1

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_version
  namespace        = var.ingress_namespace_name
  create_namespace = true

  values = [file("${var.k8s_base_path}/ingress-nginx-values.yaml")]

  depends_on = [
    # Reference the singular instance [0]
    kubectl_manifest.project_namespace[0]
  ]
}

########################################
# WAIT FOR INGRESS CONTROLLER
########################################
resource "null_resource" "wait_for_ingress_nginx" {
  count = var.cluster_create ? 0 : 1

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
  for_each = var.cluster_create ? {} : {
    serviceaccount  = "${var.k8s_base_path}/hera-submitter-sa.yaml"
    clusterrole     = "${var.k8s_base_path}/hera-submitter-role.yaml"
    binding_hera    = "${var.k8s_base_path}/hera-submitter-binding.yaml"
    binding_default = "${var.k8s_base_path}/argo-default-task-binding.yaml"
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
  for_each = var.cluster_create ? {} : var.app_configs

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
  for_each = var.cluster_create ? {} : var.app_configs

  triggers = {
    image_id     = docker_image.app[each.key].image_id
    cluster_name = var.cluster_name
  }
  provisioner "local-exec" {
    command = "kind load docker-image ${docker_image.app[each.key].name} --name ${var.cluster_name}"
  }

  depends_on = [
    kind_cluster.default,
    docker_image.app,
  ]
}

# 3. Rollout trigger (to redeploy on image rebuild) for each app using for_each
resource "null_resource" "rollout_trigger" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.cluster_create ? {} : var.app_configs

  triggers = {
    timestamp = timestamp()
  }
  depends_on = [null_resource.kind_image_load_app]
}

# 4a. Create Kubernetes StorageClass list
resource "kubectl_manifest" "storage_classes" {
  # Only execute when cluster_create is false
  for_each = var.cluster_create ? {} : var.storage_classes

  yaml_body = templatefile("${var.k8s_base_path}/storageclass.yaml", {
    name = each.value.name
    provisioner = each.value.provisioner
    reclaim_policy = each.value.reclaim_policy
    volume_binding_mode = each.value.volume_binding_mode
  })

  depends_on = [
    null_resource.kind_image_load_app,
    null_resource.rollout_trigger
  ]
}

# 4b. Create Kubernetes Deployment for each app using for_each
resource "kubectl_manifest" "app_deployment" {
  # Filter the map to only include apps that have a deployment config AND cluster_create is false
  for_each = {
    for k, v in var.app_configs : k => v
    if !var.cluster_create && try(v.deployment, null) != null
  }

  yaml_body = templatefile("${var.k8s_base_path}/deployment.yaml", {
    app_name               = each.value.metadata.app_name
    namespace_name         = var.project_namespace_name
    is_local_deployment    = var.is_local_deployment
    target_port            = each.value.metadata.target_port
    image_name             = each.value.deployment.image_name
    image_tag              = each.value.deployment.image_tag
    rollout_trigger        = null_resource.rollout_trigger[each.key].triggers.timestamp
    image_pull_secret_name = ""
    replica_count          = each.value.deployment.replica_count
    request_cpu            = each.value.deployment.request_cpu
    request_memory         = each.value.deployment.request_memory
    limit_cpu              = each.value.deployment.limit_cpu
    limit_memory           = each.value.deployment.limit_memory
    restart                = each.value.deployment.restart

    # Merge user-defined probe config with defaults
    liveness_probe_config = merge(local.default_liveness_probe, try(each.value.deployment.liveness_probe, {}))
    readiness_probe_config = merge(local.default_readiness_probe, try(each.value.deployment.readiness_probe, {}))

    app_env = merge(
      # Merge .env file contents and explicit 'environment' map
      try(
        # Map from env_file
        each.value.deployment.env_file != null ?
          {
            for line in split("\n", file("${each.value.deployment.dockerfile_path}/${each.value.deployment.env_file}")) :
            # Split on the first '=' to handle values with multiple '='
            trimspace(split("=", line, 2)[0]) => trim(split("=", line, 2)[1], "\" ")
            if length(split("=", line, 2)) == 2 # Only process lines with exactly one '='
          }
          : {}
        , {}
      ),
      # Explicit map from environment
      try(each.value.deployment.environment, {})
    )
    depends_on = try(each.value.deployment.depends_on, [])
  })

  wait = false

  depends_on = [
    null_resource.kind_image_load_app,
    null_resource.rollout_trigger,
    kubectl_manifest.storage_classes
  ]
}

# 4c. Create Kubernetes StatefulSet for each app using for_each
resource "kubectl_manifest" "app_statefulset" {
  # Filter the map to only include apps that have a statefulset config AND cluster_create is false
  for_each = {
    for k, v in var.app_configs : k => v
    if !var.cluster_create && try(v.statefulset, null) != null
  }

  yaml_body = templatefile("${var.k8s_base_path}/statefulset.yaml", {
    app_name               = each.value.metadata.app_name
    namespace_name         = var.project_namespace_name
    is_local_deployment    = var.is_local_deployment
    target_port            = each.value.metadata.target_port
    image_name             = each.value.statefulset.image_name
    image_tag              = each.value.statefulset.image_tag
    rollout_trigger        = null_resource.rollout_trigger[each.key].triggers.timestamp
    image_pull_secret_name = ""
    replica_count          = each.value.statefulset.replica_count
    request_cpu            = each.value.statefulset.request_cpu
    request_memory         = each.value.statefulset.request_memory
    limit_cpu              = each.value.statefulset.limit_cpu
    limit_memory           = each.value.statefulset.limit_memory
    data_volumes           = each.value.statefulset.data_volumes
    restart                = each.value.statefulset.restart

    # Merge user-defined probe config with defaults
    liveness_probe_config = merge(local.default_liveness_probe, try(each.value.statefulset.liveness_probe, {}))
    readiness_probe_config = merge(local.default_readiness_probe, try(each.value.statefulset.readiness_probe, {}))

    app_env = merge(
      # Merge .env file contents and explicit 'environment' map
      try(
        # Map from env_file
        each.value.statefulset.env_file != null ?
          {
            for line in split("\n", file("${each.value.statefulset.dockerfile_path}/${each.value.statefulset.env_file}")) :
            # Split on the first '=' to handle values with multiple '='
            trimspace(split("=", line, 2)[0]) => trim(split("=", line, 2)[1], "\" ")
            if length(split("=", line, 2)) == 2 # Only process lines with exactly one '='
          }
          : {}
        , {}
      ),
      # Explicit map from environment
      try(each.value.statefulset.environment, {})
    )
    depends_on = try(each.value.statefulset.depends_on, [])
  })

  wait = false

  depends_on = [
    null_resource.kind_image_load_app,
    null_resource.rollout_trigger,
    kubectl_manifest.storage_classes
  ]
}

# 5. Create Kubernetes Service for each app using for_each
resource "kubectl_manifest" "app_service" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.cluster_create ? {} : var.app_configs

  yaml_body = templatefile("${var.k8s_base_path}/service.yaml", {
    app_name            = each.value.metadata.app_name
    namespace_name      = var.project_namespace_name
    is_local_deployment = var.is_local_deployment
    target_port         = each.value.metadata.target_port
  })
  depends_on = [kubectl_manifest.app_deployment, kubectl_manifest.app_statefulset]
}

# 6. Create Kubernetes Ingress for each app that has ingress enabled
resource "kubectl_manifest" "app_ingress" {
  for_each = {
    for k, v in var.app_configs : k => v
    if !var.cluster_create && v.ingress != null
  }

  yaml_body = templatefile("${var.k8s_base_path}/ingress.yaml", {
    app_name          = each.value.metadata.app_name
    namespace_name    = var.project_namespace_name
    ingress_host      = var.ingress_host
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
  for_each = var.cluster_create ? toset([]) : toset(var.base_images_to_load) # ensure images are unique

  triggers = {
    image_name   = each.key
    cluster_name = var.cluster_name
  }
  provisioner "local-exec" {
    command = "kind load docker-image ${each.value} --name ${var.cluster_name}"
  }

  depends_on = [
    kubectl_manifest.app_ingress,
    kind_cluster.default
  ]
}
