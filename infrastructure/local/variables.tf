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

variable "argo_token" {
  description = "The dynamically generated Argo Server authentication token."
  type        = string
  default     = "" # Will be set by the output of a script
}
