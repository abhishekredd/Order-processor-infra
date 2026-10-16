variable "project_id" {
  description = "Project that owns the service accounts."
  type        = string
}

variable "accounts" {
  description = "Service accounts to create, keyed by a short static name. project_roles are project-level grants (prefer resource-level grants elsewhere)."
  type = map(object({
    account_id    = string
    display_name  = string
    description   = optional(string, "")
    project_roles = optional(list(string), [])
  }))
}
