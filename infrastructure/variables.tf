variable "cluster_create" {
  description = "A flag to determine if the cluster resource should be created."
  type        = bool
  default     = false # create resources assuming cluster already exists
}

variable "deployment_target" {
  description = "Deployment target. Can be 'local' or 'azure'."
  type        = string
  default     = "local"
}
