output "name" {
  description = "Service name. Resolves after invoker bindings exist."
  value       = google_cloud_run_v2_service.this.name
  depends_on  = [google_cloud_run_v2_service_iam_member.invokers]
}

output "uri" {
  description = "Service URL."
  value       = google_cloud_run_v2_service.this.uri
}
