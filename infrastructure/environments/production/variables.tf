variable "ghcr_pat" {
  description = "GitHub Personal Access Token with neccessary scope for GHCR."
  type        = string
  sensitive   = true
}