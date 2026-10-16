output "project_id" {
  description = "Project ID. Resolves only after APIs are enabled and propagated, so dependents wait correctly."
  value       = google_project.this.project_id
  depends_on  = [time_sleep.api_propagation]
}

output "project_number" {
  description = "Project number."
  value       = google_project.this.number
}
