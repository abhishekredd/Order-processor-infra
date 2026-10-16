data "google_project" "this" {
  project_id = var.project_id
}

locals {
  # Cloud Storage publishes object events through Pub/Sub using its own service agent.
  gcs_service_agent = "serviceAccount:service-${data.google_project.this.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "gcs_agent_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = local.gcs_service_agent
}

resource "google_eventarc_trigger" "on_upload" {
  project         = var.project_id
  name            = var.name
  location        = var.location
  service_account = var.trigger_service_account_email
  labels          = var.labels

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = var.bucket_name
  }

  destination {
    cloud_run_service {
      service = var.cloud_run_service_name
      region  = var.location
      path    = "/"
    }
  }

  depends_on = [google_project_iam_member.gcs_agent_publisher]
}
