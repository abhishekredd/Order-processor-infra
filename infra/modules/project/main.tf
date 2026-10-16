resource "random_id" "suffix" {
  count       = var.random_suffix ? 1 : 0
  byte_length = 2
}

locals {
  project_id = var.random_suffix ? "${var.project_id_prefix}-${random_id.suffix[0].hex}" : var.project_id_prefix
}

resource "google_project" "this" {
  #checkov:skip=CKV2_GCP_5:Admin Activity audit logs (incl. every IAM change) are always on. Project-wide Data Access logging adds cost and noise and is a documented prod hardening step.
  name                = var.project_name
  project_id          = local.project_id
  org_id              = var.folder_id == null ? var.org_id : null
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false # no default VPC: nothing here needs it
  deletion_policy     = var.deletion_policy
  labels              = var.labels
}

resource "google_project_service" "apis" {
  for_each                   = toset(var.apis)
  project                    = google_project.this.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "time_sleep" "api_propagation" {
  create_duration = var.api_propagation_wait
  depends_on      = [google_project_service.apis]
}
