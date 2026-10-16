variable "admin_project_id" {
  description = "EXISTING project that will hold the Terraform state bucket (e.g. a shared platform/admin project). Not created here: state must outlive the projects it manages."
  type        = string
}

variable "region" {
  description = "Location of the state bucket."
  type        = string
  default     = "asia-south1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the state bucket."
  type        = string
}
