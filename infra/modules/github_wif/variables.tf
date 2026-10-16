variable "project_id" {
  description = "Project hosting the workload identity pool."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository trusted by the provider, as OWNER/REPO."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "Must look like OWNER/REPO."
  }
}

variable "pool_id" {
  description = "Workload identity pool ID."
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "Workload identity provider ID."
  type        = string
  default     = "github"
}
