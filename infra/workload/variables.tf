variable "project_id" {
  description = "Project that hosts the processor (created by the foundation stack)."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Not a valid GCP project ID."
  }
}

variable "environment" {
  description = "Environment name; used in labels."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging or prod."
  }
}

variable "region" {
  description = "Region for all regional resources. The input bucket is created here too (EventArc requires them to match)."
  type        = string
  default     = "asia-south1"
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "retailhub-order-compat-processor"
}

variable "output_topic_name" {
  description = "Output topic name."
  type        = string
  default     = "retailhub-order-events"
}

variable "dlq_topic_name" {
  description = "Dead-letter topic name."
  type        = string
  default     = "retailhub-order-events-dlq"
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository for container images."
  type        = string
  default     = "edp-processors"
}

variable "deployer_account_id" {
  description = "Account ID of the application deployer service account created by the foundation stack."
  type        = string
  default     = "gh-deployer"
}

variable "image" {
  description = "Bootstrap container image. CI/CD owns the image after the first apply (see ignore_changes)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "cpu" {
  description = "Cloud Run CPU limit per instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Cloud Run memory limit per instance."
  type        = string
  default     = "512Mi"
}

variable "concurrency" {
  description = "Cloud Run maximum concurrent requests per instance."
  type        = number
  default     = 80
}

variable "min_instances" {
  description = "Cloud Run minimum instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Cloud Run maximum instances."
  type        = number
  default     = 2
}

variable "cloud_run_deletion_protection" {
  description = "Protect the Cloud Run service from terraform destroy."
  type        = bool
  default     = false
}

variable "bucket_force_destroy" {
  description = "Allow destroying the input bucket while it still has objects."
  type        = bool
  default     = true
}

variable "input_retention_days" {
  description = "Delete input files after this many days."
  type        = number
  default     = 30
}

variable "max_delivery_attempts" {
  description = "Delivery attempts before Pub/Sub forwards a message to the dead-letter topic."
  type        = number
  default     = 5
}

variable "contract_urn" {
  description = "URN of the Order contract in the registry."
  type        = string
  default     = "urn:edp:contract:order:1.0.0"
}

variable "contract_registry_url" {
  description = "HTTP contract registry base URL. Empty = use the contracts bundled in the image."
  type        = string
  default     = ""
}

variable "input_pattern" {
  description = "Glob of object names the processor handles."
  type        = string
  default     = "*.json"
}

variable "extra_labels" {
  description = "Extra labels merged onto labelled resources."
  type        = map(string)
  default     = {}
}
