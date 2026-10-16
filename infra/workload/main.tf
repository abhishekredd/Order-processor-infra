locals {
  bucket_name = "${var.project_id}-retailhub-input"

  labels = merge({
    app         = "retailhub-order-compat-processor"
    environment = var.environment
    managed-by  = "terraform"
  }, var.extra_labels)

  env_vars = merge({
    GCP_PROJECT           = var.project_id
    OUTPUT_TOPIC          = var.output_topic_name
    DLQ_TOPIC             = var.dlq_topic_name
    CONTRACT_URN          = var.contract_urn
    CONTRACT_REGISTRY_DIR = "/app/contracts"
    INPUT_PATTERN         = var.input_pattern
    RUN_MODE              = "gcp"
    }, var.contract_registry_url == "" ? {} : {
    CONTRACT_REGISTRY_URL = var.contract_registry_url
  })
}

# Runtime identities. The runtime account holds NO project-level roles; every grant is on a single resource.
module "service_accounts" {
  source = "../modules/service_accounts"

  project_id = var.project_id
  accounts = {
    runtime = {
      account_id   = "compat-processor"
      display_name = "Compat processor runtime"
      description  = "Runs the Cloud Run service; reads input files and publishes to Pub/Sub."
    }
    trigger = {
      account_id    = "compat-trigger"
      display_name  = "EventArc trigger"
      description   = "Used by EventArc to invoke the Cloud Run service."
      project_roles = ["roles/eventarc.eventReceiver"]
    }
  }
}

# GCS bucket for incoming RetailHub files (runtime may read)
module "storage" {
  source = "../modules/storage"

  project_id            = var.project_id
  name                  = local.bucket_name
  location              = var.region
  force_destroy         = var.bucket_force_destroy
  object_retention_days = var.input_retention_days
  readers               = { runtime = module.service_accounts.members["runtime"] }
  labels                = local.labels
}

# Output topic + subscription, dead-letter topic + dead-letter policy (runtime may publish)
module "pubsub" {
  source = "../modules/pubsub"

  project_id            = var.project_id
  output_topic_name     = var.output_topic_name
  dlq_topic_name        = var.dlq_topic_name
  publishers            = { runtime = module.service_accounts.members["runtime"] }
  max_delivery_attempts = var.max_delivery_attempts
  labels                = local.labels
}

module "artifact_registry" {
  source = "../modules/artifact_registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_repository_id
  labels        = local.labels
}

# The processor. Only the EventArc identity may invoke it.
module "cloud_run" {
  source = "../modules/cloud_run"

  project_id            = var.project_id
  name                  = var.service_name
  location              = var.region
  image                 = var.image
  service_account_email = module.service_accounts.emails["runtime"]
  env_vars              = local.env_vars
  invokers              = { eventarc_trigger = module.service_accounts.members["trigger"] }
  cpu                   = var.cpu
  memory                = var.memory
  concurrency           = var.concurrency
  min_instances         = var.min_instances
  max_instances         = var.max_instances
  deletion_protection   = var.cloud_run_deletion_protection
  labels                = local.labels
}

# New object in the bucket -> Cloud Run
module "eventarc" {
  source = "../modules/eventarc"

  project_id                    = var.project_id
  location                      = var.region
  name                          = "${var.service_name}-trigger"
  bucket_name                   = module.storage.name
  cloud_run_service_name        = module.cloud_run.name
  trigger_service_account_email = module.service_accounts.emails["trigger"]
  labels                        = local.labels
}

# ---- Resource-level grants for the application deployer (account created by the foundation stack) ----
data "google_service_account" "deployer" {
  project    = var.project_id
  account_id = var.deployer_account_id
}

resource "google_artifact_registry_repository_iam_member" "deployer_push_images" {
  project    = var.project_id
  location   = var.region
  repository = module.artifact_registry.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_service_account.deployer.email}"
}

resource "google_cloud_run_v2_service_iam_member" "deployer_update_service" {
  project  = var.project_id
  location = var.region
  name     = module.cloud_run.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.deployer.email}"
}

resource "google_service_account_iam_member" "deployer_act_as_runtime" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${module.service_accounts.emails["runtime"]}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_service_account.deployer.email}"
}
