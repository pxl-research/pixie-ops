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

  nginx_gateway_version = "v2.2.0"

  app_file_hashes_deployment = {
    for k, v in var.app_configs : k =>
    # Recursively get all files in the Docker build context
    sha1(join("", [
      for f in sort(fileset(v.deployment.docker_context, "**")) :
      # Compute and join the MD5 hash of each file
      filemd5("${v.deployment.docker_context}/${f}")
    ]))
    if !var.cluster_create && try(v.deployment, null) != null && try(v.deployment.docker_context, null) != null
  }

  app_file_hashes_statefulset = {
    for k, v in var.app_configs : k =>
    # Recursively get all files in the Docker build context
    sha1(join("", [
      for f in sort(fileset(v.statefulset.docker_context, "**")) :
      # Compute and join the MD5 hash of each file
      filemd5("${v.statefulset.docker_context}/${f}")
    ]))
    if !var.cluster_create && try(v.statefulset, null) != null && try(v.statefulset.docker_context, null) != null
  }
}

/*
resource "kind_cluster" "default" {
  count           = var.deployment_target == "local" ? 1 : 0
  name            = var.cluster_name
  kubeconfig_path = local.kube_config_path
  wait_for_ready  = true

  kind_config {
    kind          = "Cluster"
    api_version   = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }

    node {
      role = "worker"
      extra_port_mappings {
        container_port = 31007               # Matches containerPort: 31007
        host_port      = var.ingress_port    # Matches hostPort: e.g. 80
        protocol       = "TCP"               # Matches protocol: TCP (optional, as TCP is default)
      }
    }
  }
}
*/
/*
resource "null_resource" "kind_cluster_creator_no_gpu" {
  count = (var.cluster_create && var.deployment_target == "local" && !var.gpu_used) ? 1 : 0
  triggers = {
    cluster_name = var.cluster_name
    ingress_port = var.ingress_port
    config_file  = templatefile("${var.k8s_base_path}/kind-config-no-gpu.yaml", {
      ingress_port = var.ingress_port
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      CONFIG_CONTENT=$(cat <<EOF
${self.triggers.config_file}
EOF
)
      echo "$CONFIG_CONTENT" > kind_config_${var.cluster_name}.yaml
      kind create cluster --name ${var.cluster_name} --config kind_config_${var.cluster_name}.yaml
      rm kind_config_${var.cluster_name}.yaml
    EOT
    when = create
  }
}

resource "null_resource" "kind_cluster_creator_gpu" {
  count = (var.cluster_create && var.deployment_target == "local" && var.gpu_used) ? 1 : 0
  triggers = {
    cluster_name = var.cluster_name
    ingress_port = var.ingress_port
    config_file  = templatefile("${var.k8s_base_path}/kind-config-gpu.yaml", {
      ingress_port = var.ingress_port
    })
  }

  provisioner "local-exec" {
    command = <<-EOT
      CONFIG_CONTENT=$(cat <<EOF
${self.triggers.config_file}
EOF
)
      echo "$CONFIG_CONTENT" > kind_config_${var.cluster_name}.yaml
      nvkind cluster create --name ${var.cluster_name} --config-template kind_config_${var.cluster_name}.yaml
      rm kind_config_${var.cluster_name}.yaml
    EOT
    when = create
  }

}



resource "helm_release" "nvidia_device_plugin" {
  count = (var.cluster_create && var.deployment_target == "local" && var.gpu_used) ? 1 : 0

  name             = "nvidia-device-plugin"
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  chart            = "nvidia-device-plugin"
  namespace        = "nvidia"
  create_namespace = true

  depends_on = [
    null_resource.kind_cluster_creator_gpu
  ]
}
*/


# TODO: alternative cluster for Azure

resource "null_resource" "cluster_dependency" {
  count = var.deployment_target == "local" ? 1 : 0
}

resource "null_resource" "cluster_dependency_azure" {
  count = var.deployment_target == "azure" ? 1 : 0
}

resource "kubectl_manifest" "project_namespace" {
  # Only create this resource when the cluster is NOT being created in this run.
  count = var.cluster_create ? 0 : 1

  yaml_body = templatefile("${var.k8s_base_path}/namespace.yaml", {
    namespace_name = var.project_namespace_name
  })

  depends_on = [
    null_resource.cluster_dependency,
    null_resource.cluster_dependency_azure,
  ]
}

resource "null_resource" "install_nginx_gateway" {
  count = var.cluster_create ? 0 : 1

  triggers = {
    version = local.nginx_gateway_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=${local.nginx_gateway_version}" | kubectl apply -f - && kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/${local.nginx_gateway_version}/deploy/crds.yaml && kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/${local.nginx_gateway_version}/deploy/nodeport/deploy.yaml && kubectl wait --namespace nginx-gateway --for=condition=Available deployment/nginx-gateway --timeout=300s && kubectl patch nginxproxy nginx-gateway-proxy-config -n nginx-gateway --type='merge' -p='{"spec":{"kubernetes":{"service":{"nodePorts":[{"port":31007,"listenerPort":${var.ingress_port}}]}}}}'
    EOT

    environment = {
      KUBECONFIG = local.kube_config_path
    }
  }

  depends_on = [
    kubectl_manifest.project_namespace[0]
  ]
}

resource "null_resource" "install_local_path_provisioner" {
  count = (!var.cluster_create && var.deployment_target == "local") ? 1 : 0
  triggers = {
    version = "v0.0.32"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.32/deploy/local-path-storage.yaml && kubectl wait --for=condition=Available -n local-path-storage deployment/local-path-provisioner --timeout=300s"

    environment = {
      KUBECONFIG = local.kube_config_path
    }
  }

  depends_on = [
    null_resource.cluster_dependency,
    null_resource.cluster_dependency_azure,
    kubectl_manifest.project_namespace[0]
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
  namespace        = var.project_namespace_name
  create_namespace = false

  values = [file("${var.k8s_base_path}/argo-workflows-values.yaml")]

  depends_on = [
    # Reference the singular instance [0]
    kubectl_manifest.project_namespace[0]
  ]
}

resource "kubectl_manifest" "http_gateway" {
  count = var.cluster_create ? 0 : 1
  yaml_body = templatefile(
    "${var.k8s_base_path}/gateway.yaml", {
      project_namespace_name = var.project_namespace_name
      ingress_host = var.ingress_host
      ingress_port = var.ingress_port
    }
  )
  depends_on = [null_resource.install_nginx_gateway]
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

  yaml_body = templatefile(each.value, {
      project_namespace_name = var.project_namespace_name
    }
  )

  depends_on = [
    # Reference the singular instances [0]
    helm_release.argo_workflows[0],
    null_resource.install_nginx_gateway,
    null_resource.install_local_path_provisioner
  ]
}


########################################
# DYNAMIC APP DEPLOYMENT (IMAGE BUILD, LOAD, K8S MANIFESTS)
########################################

# Build the local Docker image for each app using for_each
resource "docker_image" "app" {
  for_each = {
    for k, v in var.app_configs : k => v
    if !var.cluster_create && ((v.deployment != null && v.deployment.docker_context != null) || (v.statefulset != null && v.statefulset.docker_context != null))
  }

  name = (each.value.deployment != null) ? "${each.value.deployment.image_name}:${each.value.deployment.image_tag}" : "${each.value.statefulset.image_name}:${each.value.statefulset.image_tag}"

  build {
    context    = (each.value.deployment != null) ? each.value.deployment.docker_context : each.value.statefulset.docker_context
    dockerfile = (each.value.deployment != null) ? "${each.value.deployment.dockerfile_path}/Dockerfile"  : "${each.value.statefulset.dockerfile_path}/Dockerfile"
  }

  triggers = {
    source_hash = coalesce(
      try(local.app_file_hashes_deployment[each.key], null),
      try(local.app_file_hashes_statefulset[each.key], null)
    )
  }

  depends_on = [
    kubectl_manifest.hera_rbac
  ]
}

resource "docker_image" "remote_app" {
  for_each = {
    for k, v in var.app_configs : k => v
    if !var.cluster_create && ((v.deployment != null && v.deployment.docker_context == null) || (v.statefulset != null && v.statefulset.docker_context == null))
  }
  # The name MUST include the full registry path for pulling remote images,
  # e.g., ghcr.io/org/repo/image:tag
  name = (each.value.deployment != null) ? "${each.value.deployment.image_name}:${each.value.deployment.image_tag}" : "${each.value.statefulset.image_name}:${each.value.statefulset.image_tag}"
  # The 'pull_trigger' ensures the image is pulled if it doesn't exist or if the source changes.
  pull_triggers =  (each.value.deployment != null) ? [each.value.deployment.image_tag] : [each.value.statefulset.image_tag]
  depends_on = [
    kubectl_manifest.hera_rbac
  ]
}

resource "null_resource" "rollout_trigger_deployment" {
  # Ensure the keys match those used in the kubectl_manifest (each.key)
  for_each = local.app_file_hashes_deployment

  triggers = {
    # Use the computed file hash as the trigger value
    app_source_hash = each.value
  }

  # This depends on the docker image being built before the deployment is triggered
  depends_on = [
    docker_image.app
  ]
}

resource "null_resource" "rollout_trigger_statefulset" {
  # Ensure the keys match those used in the kubectl_manifest (each.key)
  for_each = local.app_file_hashes_statefulset

  triggers = {
    # Use the computed file hash as the trigger value
    app_source_hash = each.value
  }

  # This depends on the docker image being built before the deployment is triggered
  depends_on = [
    docker_image.app
  ]
}

# 2. Load the image into Kind for each app using for_each
resource "null_resource" "kind_image_load_app" {
  for_each = (!var.cluster_create && var.deployment_target == "local") ? merge(docker_image.app, docker_image.remote_app) : {}
  #for_each = (var.cluster_create) ? {} : var.app_configs

  triggers = {
    # Safe lookup for the ID (ensures image is ready)
    image_id     = try(docker_image.app[each.key].image_id, docker_image.remote_app[each.key].image_id)
    # Safe lookup for the NAME (used in the command)
    image_name   = try(docker_image.app[each.key].name, docker_image.remote_app[each.key].name)
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    # Use the name calculated in the triggers block
    # command = "kind load docker-image ${self.triggers.image_name} --name ${var.cluster_name}"
    command = "minikube image load ${self.triggers.image_name}"
  }

  depends_on = [
    kubectl_manifest.project_namespace[0],
    docker_image.app,
    docker_image.remote_app,
  ]
}

# 3. Rollout trigger (to redeploy on image rebuild) for each app using for_each
resource "null_resource" "rollout_trigger" {
  # Use conditional map: empty map if true, app_configs if false
  for_each = var.cluster_create ? {} : var.app_configs

  triggers = {
    timestamp = timestamp()
  }
  depends_on = [
    null_resource.cluster_dependency,
    null_resource.cluster_dependency_azure
  ]
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

  wait = true

  depends_on = [
    null_resource.cluster_dependency,
    null_resource.cluster_dependency_azure,
    kubectl_manifest.project_namespace,
    null_resource.rollout_trigger
  ]
}

locals {
  get_dep_ready_path = {
    for dep_app_name, dep_config in var.app_configs :
    dep_app_name => (
      try(dep_config.deployment.readiness_probe.path, null) != null ? dep_config.deployment.readiness_probe.path :
      try(dep_config.statefulset.readiness_probe.path, null) != null ? dep_config.statefulset.readiness_probe.path :
      "/readyz"
    )
  }

  depends_on_details = {
    for app_name, app_cfg in var.app_configs :
    app_name => {
      for dep_app_name, dep_override in try(app_cfg.deployment.depends_on, {}) :
      dep_app_name => merge(
        {
          service_port = var.app_configs[dep_app_name].metadata.service_port
          ready_path   = local.get_dep_ready_path[dep_app_name]
        },
        dep_override
      )
    }
  }
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
    service_port        = each.value.metadata.service_port
  })
  depends_on = [
    null_resource.cluster_dependency,
    null_resource.cluster_dependency_azure,

    null_resource.rollout_trigger_deployment,
    null_resource.rollout_trigger_statefulset,
    kubectl_manifest.storage_classes,
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
    rollout_trigger        = try(null_resource.rollout_trigger_deployment[each.key].triggers.app_source_hash, "")
    image_pull_secret_name = ""
    replica_count          = each.value.deployment.replica_count
    request_cpu            = each.value.deployment.request_cpu
    request_memory         = each.value.deployment.request_memory
    limit_cpu              = each.value.deployment.limit_cpu
    limit_memory           = each.value.deployment.limit_memory
    restart                = each.value.deployment.restart
    platform_os            = each.value.deployment.platform_os
    platform_architecture  = each.value.deployment.platform_architecture

    # Merge user-defined probe config with defaults
    liveness_probe_config = merge(local.default_liveness_probe, try(each.value.deployment.liveness_probe, {}))
    readiness_probe_config = merge(local.default_readiness_probe, try(each.value.deployment.readiness_probe, {}))

    app_env = merge(
      // Conditional map creation
      (
        each.value.deployment.env_file != null
        ? {
          # TRUE path: Execute the complex regex parsing and mapping
          for kv in regexall(
            "(?m)^([A-Za-z_][A-Za-z0-9_]*)=(.*)$",
            file("${each.value.deployment.dockerfile_path}/${each.value.deployment.env_file}")
          ) :
          trim(kv[0], " ") => replace(trim(kv[1], " "), "^\"|\"$", "")
        }
      : {}
        # FALSE path: Return an empty map if env_file is null or empty
      ),
      // Always merge with the explicit 'environment' variables, if they exist
      try(each.value.deployment.environment, {})
    )
    # depends_on = try(each.value.deployment.depends_on, [])
    depends_on_details = try(local.depends_on_details[each.key], {})
  })

  wait = false # Important to avoid timeouts!!!

  depends_on = [
    kubectl_manifest.app_service,
    null_resource.rollout_trigger_deployment,
    null_resource.kind_image_load_app
  ]
}


# 4c. Create Kubernetes StatefulSet for each app using for_each
resource "kubectl_manifest" "app_statefulset" {
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
      rollout_trigger        = null_resource.rollout_trigger_statefulset[each.key].triggers.app_source_hash
      image_pull_secret_name = ""
      replica_count          = each.value.statefulset.replica_count
      request_cpu            = each.value.statefulset.request_cpu
      request_memory         = each.value.statefulset.request_memory
      limit_cpu              = each.value.statefulset.limit_cpu
      limit_memory           = each.value.statefulset.limit_memory
      data_volumes           = each.value.statefulset.data_volumes
      restart                = each.value.statefulset.restart
      platform_os            = each.value.statefulset.platform_os
      platform_architecture  = each.value.statefulset.platform_architecture
      liveness_probe_config  = merge(local.default_liveness_probe, try(each.value.statefulset.liveness_probe, {}))
      readiness_probe_config = merge(local.default_readiness_probe, try(each.value.statefulset.readiness_probe, {}))
      app_env                = merge(
        each.value.statefulset.env_file != null
        ? {
            for kv in regexall(
              "(?m)^([A-Za-z_][A-Za-z0-9_]*)=(.*)$",
              file("${each.value.statefulset.dockerfile_path}/${each.value.statefulset.env_file}")
            ) : trim(kv[0], " ") => replace(trim(kv[1], " "), "^\"|\"$", "")
          }
        : {},
        try(each.value.statefulset.environment, {})
      )
      depends_on_details = try(local.depends_on_details[each.key], {})
  })

  wait = false

  depends_on = [
    kubectl_manifest.app_service,
    null_resource.rollout_trigger_statefulset,
    null_resource.kind_image_load_app
  ]
}

# 6. Create Kubernetes Ingress for each app that has ingress enabled
resource "kubectl_manifest" "http_route" {
  for_each = {
    for k, v in var.app_configs : k => v
    if !var.cluster_create && v.ingress != null
  }

  yaml_body = templatefile("${var.k8s_base_path}/httproute.yaml", {
    app_name          = each.value.metadata.app_name
    namespace_name    = var.project_namespace_name
    ingress_host      = var.ingress_host
    ingress_path      = each.value.ingress.path
    ingress_port      = var.ingress_port
    gateway_name      = "${var.project_namespace_name}-gateway"
    gateway_namespace = var.project_namespace_name
  })

  depends_on = [
    kubectl_manifest.http_gateway,
    #kubectl_manifest.reference_grant
  ]
}

########################################
# HERA BASE IMAGE LOAD
########################################
resource "docker_image" "base" {
  for_each = var.cluster_create ? {} : { for img in var.base_images_to_load : img => img }

  name = each.value
}
resource "null_resource" "kind_image_load_base_images" {
  for_each = var.cluster_create ? {} : { for img in var.base_images_to_load : img => img }

  triggers = {
    image_name   = each.key
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    # command = "kind load docker-image ${docker_image.base[each.key].name} --name ${var.cluster_name}"
    command = "minikube image load ${docker_image.base[each.key].name}"
  }

  depends_on = [
    null_resource.cluster_dependency,
    null_resource.cluster_dependency_azure,
    docker_image.base,
    kubectl_manifest.http_route,
  ]
}

output "file_hashes_deployment" {
  value = local.app_file_hashes_deployment
}

output "file_hashes_statefulset" {
  value = local.app_file_hashes_statefulset
}
