output "project_id" {
  description = "The created project's ID."
  value       = module.project.project_id
}

output "project_number" {
  description = "The created project's number."
  value       = module.project.project_number
}

output "workload_identity_provider" {
  description = "Provider resource name for google-github-actions/auth."
  value       = module.github_wif.provider_name
}

output "tf_plan_service_account" {
  description = "Read-only identity for pull-request plans."
  value       = module.ci_identities.emails["tf_plan"]
}

output "tf_apply_service_account" {
  description = "Identity that applies the workload stack."
  value       = module.ci_identities.emails["tf_apply"]
}

output "deployer_service_account" {
  description = "Identity that deploys application images."
  value       = module.ci_identities.emails["deployer"]
}

output "github_repository_variables" {
  description = "Copy these into GitHub: Settings > Secrets and variables > Actions > Variables."
  value = {
    GCP_PROJECT_ID  = module.project.project_id
    GCP_REGION      = var.region
    WIF_PROVIDER    = module.github_wif.provider_name
    TF_PLAN_SA      = module.ci_identities.emails["tf_plan"]
    TF_APPLY_SA     = module.ci_identities.emails["tf_apply"]
    DEPLOYER_SA     = module.ci_identities.emails["deployer"]
    TF_STATE_BUCKET = var.state_bucket_name
  }
}
