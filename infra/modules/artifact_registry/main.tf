resource "google_artifact_registry_repository" "this" {
  #checkov:skip=CKV_GCP_84:Google-managed encryption is accepted; customer-managed keys need a KMS setup that is out of scope.
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Container images for compatibility processors"
  labels        = var.labels

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "${var.delete_older_than_days * 86400}s"
    }
  }
}
