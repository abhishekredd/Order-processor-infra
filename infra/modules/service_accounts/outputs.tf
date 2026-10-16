output "emails" {
  description = "Map of account key -> email. Resolves after project-level roles are bound."
  value       = { for k, sa in google_service_account.this : k => sa.email }
  depends_on  = [google_project_iam_member.project_roles]
}

output "members" {
  description = "Map of account key -> IAM member string (serviceAccount:...)."
  value       = { for k, sa in google_service_account.this : k => "serviceAccount:${sa.email}" }
  depends_on  = [google_project_iam_member.project_roles]
}
