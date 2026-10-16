resource "google_storage_bucket" "this" {
  #checkov:skip=CKV_GCP_62:Object access is recorded by Cloud Audit Logs; dedicated access-log buckets are out of scope for this stack.
  project                     = var.project_id
  name                        = var.name
  location                    = var.location
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = var.object_retention_days > 0 ? [1] : []
    content {
      condition {
        age = var.object_retention_days
      }
      action {
        type = "Delete"
      }
    }
  }

  # With versioning on, superseded/deleted versions are purged after the same window.
  dynamic "lifecycle_rule" {
    for_each = var.versioning_enabled && var.object_retention_days > 0 ? [1] : []
    content {
      condition {
        days_since_noncurrent_time = var.object_retention_days
      }
      action {
        type = "Delete"
      }
    }
  }
}

resource "google_storage_bucket_iam_member" "readers" {
  for_each = var.readers
  bucket   = google_storage_bucket.this.name
  role     = "roles/storage.objectViewer"
  member   = each.value
}
