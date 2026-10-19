resource "google_cloud_run_v2_service" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.location
  ingress             = "INGRESS_TRAFFIC_ALL" # still IAM-protected: callers need run.invoker
  deletion_protection = var.deletion_protection
  labels              = var.labels

  template {
    service_account = var.service_account_email
    timeout         = "${var.timeout_seconds}s"

    max_instance_request_concurrency = var.concurrency

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  lifecycle {
    # CI/CD deploys new images with `gcloud run deploy`; Terraform must not roll them back.
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
      # Google reports a service-level `scaling` block (all zeros) that we never set. Instance counts are
      # managed in `template[0].scaling`, which is NOT ignored. Without this, every plan proposes removing it.
      scaling,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = var.invokers
  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = each.value
}
