variable "cluster_create" {
  description = "A flag to determine if the cluster resource should be created."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "The name to assign to the Kubernetes cluster (e.g., kind cluster name)."
  type        = string
  default     = "kind"
}

variable "argo_namespace_name" {
  description = "The Kubernetes namespace where Argo Workflows will be installed."
  type        = string
  default     = "argo"
}

variable "project_namespace_name" {
  description = "The primary Kubernetes namespace for the application deployment."
  type        = string
  default     = "default"
}

variable "ingress_namespace_name" {
  description = "The Kubernetes namespace where the Ingress Controller will be installed."
  type        = string
  default     = "ingress-nginx"
}

variable "storage_classes" {
  description = "A map of storage class configurations, where the map keys are local references and the values define the properties of the StorageClass object."
  type = map(object({
    name                = string
    provisioner         = string
    reclaim_policy      = string
    volume_binding_mode = string
  }))
  default = {}
}

variable "app_configs" {
  description = "A map containing configuration details for dynamic application deployment (Docker, k8s manifest values)."
  type = map(object({

    metadata = object({
      app_name    = string
      target_port = number
    })

    deployment = optional(object({
      replica_count      = number
      has_probing        = bool
      image_name         = string
      image_tag          = string
      docker_context     = string
      dockerfile_path    = string
      request_cpu        = string
      request_memory     = string
      limit_cpu          = string
      limit_memory       = string
      env_file           = optional(string, null)
    }), null)

    statefulset = optional(object({
      replica_count    = number
      has_probing      = bool
      image_name       = string
      image_tag        = string
      docker_context   = string
      dockerfile_path  = string
      request_cpu      = string
      request_memory   = string
      limit_cpu        = string
      limit_memory     = string
      env_file         = optional(string, null)
      data_volumes = map(object({
        name               = string
        mount_path         = string
        storage_request    = string
        storage_class_name = string
        access_mode        = string
      }))
    }), null)

    service = optional(object({
      type = string
    }), null)

    ingress = optional(object({
      path = string
    }), null)
  }))
  default = {}
}

variable "k8s_base_path" {
  description = "The relative path to the base Kubernetes manifest templates."
  type        = string
  default     = "./../kubernetes"
}

variable "base_images_to_load" {
  description = "A list of Docker images to pre-load into the Kind cluster for Argo Workflows."
  type        = list(string)
  default     = []
}

variable "is_local_deployment" {
  description = "Boolean indicating if the deployment is targeting a local cluster (e.g., kind). Used for image pull policies."
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "The host name to configure in the Kubernetes Ingress resources."
  type        = string
  default     = "localhost"
}

variable "ingress_version" {
  description = "The chart version for the NGINX Ingress Controller Helm release."
  type        = string
  default     = "4.7.1"
}

variable "argo_workflows_version" {
  description = "The chart version for the Argo Workflows Helm release."
  type        = string
  default     = "0.45.26"
}
