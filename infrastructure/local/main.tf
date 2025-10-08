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
  depends_on = [
    kubernetes_namespace.argo_namespace
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