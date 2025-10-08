locals {
  app_name = "pixie-ingest"
}

resource "kubernetes_namespace" "argo_namespace" {
  provider = kubernetes.minikube_conn
  metadata {
    name = "argo"
  }
}

resource "helm_release" "argo_workflows" {
  provider   = helm.minikube_conn 
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  namespace  = kubernetes_namespace.argo_namespace.metadata.0.name
  values = [
    file("${path.module}/../../kubernetes/base/argo-workflows-values.yaml")
  ]
}

resource "kubectl_manifest" "hera_rbac" {
  for_each = {
    serviceaccount = "${path.module}/../../kubernetes/base/hera-submitter-sa.yaml"
    clusterrole    = "${path.module}/../../kubernetes/base/hera-submitter-role.yaml"
    binding_hera   = "${path.module}/../../kubernetes/base/hera-submitter-binding.yaml"
    binding_default = "${path.module}/../../kubernetes/base/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    helm_release.argo_workflows,
    kubernetes_namespace.argo_namespace
  ]
}


/* resource "null_resource" "install_argo" {
  depends_on = [
    kubernetes_namespace.argo_namespace
  ]

  provisioner "local-exec" {
    command = "kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.7.2/install.yaml"
  }
}
 */


# # 6. Hera RBAC and service account
# resource "null_resource" "hera_rbac" {
#   depends_on = [null_resource.install_argo]

#   provisioner "local-exec" {
#     command = <<EOT
# # Create Hera service account
# kubectl create serviceaccount hera-submitter -n argo || echo "ServiceAccount exists"

# # Bind cluster role
# kubectl create clusterrolebinding argo-default-task-binding \
#   --clusterrole=hera-submitter-role \
#   --serviceaccount=argo:default || echo "Binding exists"

# # Apply Hera manifests
# kubectl apply -n argo -f ${path.module}/../../kubernetes/base/hera-binding.yaml
# kubectl apply -n argo -f ${path.module}/../../kubernetes/base/hera-submitter-role.yaml

# # Patch argo-server deployment for server auth
# kubectl patch deployment argo-server -n argo --type='json' \
#   -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--auth-mode=server"}]'
# EOT
#   }
# }

# # Capture the Argo token as a Terraform variable
# data "external" "argo_token" {
#   depends_on = [null_resource.hera_rbac]

#   program = [
#     "bash",
#     "-c",
#     <<EOF
# set -e
# token=$(kubectl create token hera-submitter -n argo)
# echo "{\"argo_token\": \"Bearer $${token}\"}"
# EOF
#   ]
# }


# # 0. Execute minikube setup script
# resource "null_resource" "setup_minikube" {
#   depends_on = [
#     null_resource.hera_rbac,
#     data.external.argo_token
#   ]
  
#   triggers = {
#     always_run = timestamp()
#   }

#   provisioner "local-exec" {
#     environment = {
#       ARGO_TOKEN = data.external.argo_token.result.argo_token
#     }
#     command = "bash ./minikube_setup.sh"
#     when    = create
#   }
# }

# # 1. Create the Kubernetes Namespace for the application
# resource "kubernetes_manifest" "pixie_namespace" {
#   depends_on = [null_resource.setup_minikube, null_resource.install_argo, null_resource.hera_rbac]

#   manifest = {
#     apiVersion = "v1"
#     kind       = "Namespace"
#     metadata = {
#       name = "pixie"
#     }
#   }
# }

# # 2. Apply Deployment Manifest
# resource "kubernetes_manifest" "app_deployment" {
#   depends_on = [
#     kubernetes_manifest.pixie_namespace,
#     null_resource.install_argo,
#     null_resource.hera_rbac
#   ]

#   manifest = yamldecode(
#     templatefile("${path.module}/../../kubernetes/base/deployment.yaml", {
#       app_name   = local.app_name
#       image_name = var.image_name
#       image_tag  = var.image_tag
#     })
#   )
# }

# # 3. Apply Service Manifest
# resource "kubernetes_manifest" "app_service" {
#   depends_on = [
#     kubernetes_manifest.app_deployment,
#     null_resource.install_argo,
#     null_resource.hera_rbac
#   ]

#   manifest = yamldecode(
#     templatefile("${path.module}/../../kubernetes/base/service.yaml", {
#       app_name = local.app_name
#     })
#   )
# }
