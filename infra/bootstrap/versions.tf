terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = var.admin_project_id
  region  = var.region

  # Bill API calls to the admin project itself, so no `gcloud ... set-quota-project` step is needed.
  user_project_override = true
  billing_project       = var.admin_project_id
}
