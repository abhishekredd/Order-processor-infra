variable "project_id" {
  description = "Project that owns the bucket."
  type        = string
}

variable "name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "location" {
  description = "Bucket location. Must match the EventArc trigger region for regional buckets."
  type        = string
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket. Keep false outside dev."
  type        = bool
  default     = false
}

variable "object_retention_days" {
  description = "Delete objects older than this many days (0 disables)."
  type        = number
  default     = 30
}

variable "versioning_enabled" {
  description = "Keep previous versions of overwritten or deleted objects, protecting source files from accidental overwrite."
  type        = bool
  default     = true
}

variable "readers" {
  description = "Map of static key -> IAM member granted roles/storage.objectViewer."
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "Bucket labels."
  type        = map(string)
  default     = {}
}
