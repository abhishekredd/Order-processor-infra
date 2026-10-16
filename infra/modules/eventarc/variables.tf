variable "project_id" {
  description = "Project that owns the trigger."
  type        = string
}

variable "location" {
  description = "Trigger region. For a regional bucket this must equal the bucket's region."
  type        = string
}

variable "name" {
  description = "Trigger name."
  type        = string
}

variable "bucket_name" {
  description = "Bucket whose object-finalized events fire the trigger."
  type        = string
}

variable "cloud_run_service_name" {
  description = "Destination Cloud Run service."
  type        = string
}

variable "trigger_service_account_email" {
  description = "Identity EventArc uses to call the service (needs run.invoker and eventarc.eventReceiver)."
  type        = string
}

variable "labels" {
  description = "Trigger labels."
  type        = map(string)
  default     = {}
}
