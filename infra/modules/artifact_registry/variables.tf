variable "project_id" {
  description = "Project that owns the repository."
  type        = string
}

variable "location" {
  description = "Repository region."
  type        = string
}

variable "repository_id" {
  description = "Repository name."
  type        = string
}

variable "keep_recent_versions" {
  description = "Always keep this many most-recent image versions."
  type        = number
  default     = 10
}

variable "delete_older_than_days" {
  description = "Delete versions older than this many days, unless protected by keep_recent_versions."
  type        = number
  default     = 30
}

variable "labels" {
  description = "Repository labels."
  type        = map(string)
  default     = {}
}
