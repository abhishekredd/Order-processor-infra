variable "environment" {
  description = "Environment name; used in labels."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging or prod."
  }
}

variable "project_id_prefix" {
  description = "Prefix of the new project's ID, e.g. retailhub-compat-dev."
  type        = string
}

variable "project_name" {
  description = "Display name of the new project."
  type        = string
}

variable "random_suffix" {
  description = "Append a random suffix to the project ID (project IDs are globally unique and never reusable)."
  type        = bool
  default     = true
}

variable "billing_account" {
  description = "Billing account ID to attach."
  type        = string
}

variable "org_id" {
  description = "Organization ID (null if using folder_id or a standalone project)."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "Folder ID (takes precedence over org_id)."
  type        = string
  default     = null
}

variable "quota_project" {
  description = "Existing project used for API quota while creating the new project (null to skip)."
  type        = string
  default     = null
}

variable "project_deletion_policy" {
  description = "PREVENT, ABANDON or DELETE for the project resource."
  type        = string
  default     = "PREVENT"
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "asia-south1"
}

variable "github_repo" {
  description = "GitHub repository (OWNER/REPO) whose workflows may authenticate to this project."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may apply infrastructure and deploy the app. Configure required reviewers on it."
  type        = string
  default     = "dev"
}

variable "state_bucket_name" {
  description = "Existing Terraform state bucket (created by infra/bootstrap)."
  type        = string
}

variable "extra_labels" {
  description = "Extra labels merged onto labelled resources."
  type        = map(string)
  default     = {}
}
