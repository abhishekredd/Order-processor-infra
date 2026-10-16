provider "google" {
  region = var.region

  # Creating projects with user credentials needs a quota project that already has the
  # resource-manager/billing APIs enabled. Set quota_project to your admin project.
  user_project_override = var.quota_project != null
  billing_project       = var.quota_project
}
