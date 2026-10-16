variable "project_id" {
  description = "Project that owns the service."
  type        = string
}

variable "name" {
  description = "Cloud Run service name."
  type        = string
}

variable "location" {
  description = "Cloud Run region."
  type        = string
}

variable "image" {
  description = "Initial container image. After creation the image is owned by CI/CD (see lifecycle.ignore_changes)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "service_account_email" {
  description = "Runtime identity of the service."
  type        = string
}

variable "env_vars" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "invokers" {
  description = "Map of static key -> IAM member allowed to invoke the service (roles/run.invoker)."
  type        = map(string)
  default     = {}
}

variable "min_instances" {
  description = "Minimum instances (0 = scale to zero)."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances."
  type        = number
  default     = 5
}

variable "cpu" {
  description = "CPU limit per instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per instance."
  type        = string
  default     = "512Mi"
}

variable "concurrency" {
  description = "Maximum concurrent requests per instance."
  type        = number
  default     = 80
}

variable "timeout_seconds" {
  description = "Request timeout."
  type        = number
  default     = 300
}

variable "deletion_protection" {
  description = "Block `terraform destroy` of the service."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Service labels."
  type        = map(string)
  default     = {}
}
