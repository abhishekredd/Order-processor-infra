variable "project_id_prefix" {
  description = "Project ID (or prefix of it when random_suffix = true). Lowercase letters, digits, hyphens."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{3,23}[a-z0-9]$", var.project_id_prefix))
    error_message = "Must be 5-25 chars, start with a letter, end with a letter/digit, only lowercase letters, digits and hyphens (leaves room for a 5-char random suffix)."
  }
}

variable "project_name" {
  description = "Human-readable project name."
  type        = string
}

variable "random_suffix" {
  description = "Append a random 4-hex suffix to make the globally-unique project ID collision-proof."
  type        = bool
  default     = true
}

variable "billing_account" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX) to attach to the project."
  type        = string
}

variable "org_id" {
  description = "Organization ID to create the project under. Ignored when folder_id is set. Leave both null for a standalone project."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "Folder ID (numeric) to create the project under."
  type        = string
  default     = null
}

variable "apis" {
  description = "Google APIs to enable on the project."
  type        = list(string)
}

variable "labels" {
  description = "Labels applied to the project."
  type        = map(string)
  default     = {}
}

variable "deletion_policy" {
  description = "PREVENT blocks `terraform destroy` of the project; DELETE allows it."
  type        = string
  default     = "PREVENT"
  validation {
    condition     = contains(["PREVENT", "ABANDON", "DELETE"], var.deletion_policy)
    error_message = "Must be PREVENT, ABANDON or DELETE."
  }
}

variable "api_propagation_wait" {
  description = "Pause after enabling APIs so they are usable by dependent resources (API enablement is eventually consistent)."
  type        = string
  default     = "60s"
}
