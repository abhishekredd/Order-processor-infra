output "project_id" {
  description = "Project hosting the processor."
  value       = var.project_id
}

output "region" {
  description = "Region of all regional resources."
  value       = var.region
}

output "input_bucket" {
  description = "Upload RetailHub JSON files here."
  value       = module.storage.name
}

output "output_topic" {
  description = "Topic receiving valid CloudEvents."
  value       = module.pubsub.output_topic_name
}

output "dlq_topic" {
  description = "Dead-letter topic."
  value       = module.pubsub.dlq_topic_name
}

output "output_verify_subscription" {
  description = "Pull this to see valid events."
  value       = module.pubsub.output_subscription
}

output "dlq_verify_subscription" {
  description = "Pull this to see dead-lettered messages."
  value       = module.pubsub.dlq_subscription
}

output "service_name" {
  description = "Cloud Run service name."
  value       = module.cloud_run.name
}

output "service_url" {
  description = "Cloud Run URL (IAM-protected)."
  value       = module.cloud_run.uri
}

output "image_repository" {
  description = "Push images to <this>/<service>:<tag>."
  value       = module.artifact_registry.url
}

output "eventarc_trigger" {
  description = "EventArc trigger name."
  value       = module.eventarc.trigger_name
}

output "runtime_service_account" {
  description = "Identity the processor runs as."
  value       = module.service_accounts.emails["runtime"]
}

output "trigger_service_account" {
  description = "Identity EventArc uses to invoke the processor."
  value       = module.service_accounts.emails["trigger"]
}
