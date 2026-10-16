# Run ONCE with local state. Every stack (foundation, workload) then stores its state here.
locals {
  # What the foundation stack needs from the admin project to create and bill a new project.
  admin_apis = [
    "cloudresourcemanager.googleapis.com", # create projects
    "cloudbilling.googleapis.com",         # link them to the billing account
    "serviceusage.googleapis.com",         # enable APIs on them
    "storage.googleapis.com",              # this state bucket
    "iam.googleapis.com",                  # service accounts / workload identity
  ]
}

resource "google_project_service" "admin_apis" {
  for_each           = toset(local.admin_apis)
  project            = var.admin_project_id
  service            = each.value
  disable_on_destroy = false # other things in the admin project may rely on them
}

resource "google_storage_bucket" "tfstate" {
  #checkov:skip=CKV_GCP_62:State-bucket access is covered by Cloud Audit Logs; a dedicated access-log bucket is out of scope.
  name                        = var.state_bucket_name
  project                     = var.admin_project_id
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true # every state revision is recoverable
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 30
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.admin_apis]
}
