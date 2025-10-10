locals {
  app_name_ingest_server = "pixie-ingest"
  app_path_ingest_server = "${path.module}/../../../apps/ingest_server"
  k8s_path_ingest_server = "${path.module}/../../../kubernetes/apps/ingest_server"

  argo_namespace_name = "argo"
  pixie_namespace_name = "pixie"
}

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
  namespace  = kubernetes_namespace.argo_namespace.metadata.0.name
  values = [
    file("${path.module}/../../../kubernetes/base/argo-workflows-values.yaml")
  ]
  depends_on = [
    kubernetes_namespace.argo_namespace
  ]
}

resource "kubectl_manifest" "hera_rbac" {
  for_each = {
    serviceaccount = "${path.module}/../../../kubernetes/base/hera-submitter-sa.yaml"
    clusterrole    = "${path.module}/../../../kubernetes/base/hera-submitter-role.yaml"
    binding_hera   = "${path.module}/../../../kubernetes/base/hera-submitter-binding.yaml"
    binding_default = "${path.module}/../../../kubernetes/base/argo-default-task-binding.yaml"
  }

  yaml_body = file(each.value)

  depends_on = [
    helm_release.argo_workflows,
    kubernetes_namespace.argo_namespace
  ]
}