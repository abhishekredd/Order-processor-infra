output "repository_id" {
  description = "Repository ID."
  value       = google_artifact_registry_repository.this.repository_id
}

output "url" {
  description = "Docker registry URL prefix, e.g. REGION-docker.pkg.dev/PROJECT/REPO."
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
