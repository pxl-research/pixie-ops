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
