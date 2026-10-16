output "pool_name" {
  description = "Full pool resource name (projects/N/locations/global/workloadIdentityPools/POOL), used to build principal identifiers."
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_name" {
  description = "Full provider resource name, for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}
