variable "argo_workflows_manifest_url" {
  description = "URL to the Argo Workflows installation manifest"
  type        = string
  default     = "https://github.com/argoproj/argo-workflows/releases/download/v3.7.2/install.yaml"
}

variable "image_name" {
  default = "pixie-ingest"
  description = "The name of the container image."
  type = string
}

variable "image_tag" {
  default = "latest"
  description = "The tag (version) of the container image."
  type = string
}
