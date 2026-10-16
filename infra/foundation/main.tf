locals {
  project_id = module.project.project_id

  labels = merge({
    app         = "retailhub-order-compat-processor"
    environment = var.environment
    managed-by  = "terraform"
  }, var.extra_labels)

  # Everything the workload stack and the pipelines need.
  apis = [
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  # PLAN identity: can read everything, change nothing.
  plan_roles = [
    "roles/viewer",               # read resources
    "roles/iam.securityReviewer", # read IAM policies (viewer alone cannot)
  ]

  # APPLY identity: administer exactly the services the workload stack manages.
  apply_roles = [
    "roles/run.admin",                       # Cloud Run service + invoker bindings
    "roles/pubsub.admin",                    # topics, subscriptions, their IAM
    "roles/storage.admin",                   # input bucket + its IAM
    "roles/artifactregistry.admin",          # image repository + its IAM
    "roles/eventarc.admin",                  # the trigger
    "roles/iam.serviceAccountAdmin",         # create runtime/trigger accounts
    "roles/iam.serviceAccountUser",          # actAs runtime/trigger when wiring them to services
    "roles/resourcemanager.projectIamAdmin", # project-level bindings (eventReceiver, GCS agent)
  ]

  # Token subject GitHub issues to a job that declares `environment: <name>`.
  environment_subject = "repo:${var.github_repo}:environment:${var.github_environment}"
}

# 1. The project and its APIs
module "project" {
  source = "../modules/project"

  project_id_prefix = var.project_id_prefix
  project_name      = var.project_name
  random_suffix     = var.random_suffix
  billing_account   = var.billing_account
  org_id            = var.org_id
  folder_id         = var.folder_id
  apis              = local.apis
  labels            = local.labels
  deletion_policy   = var.project_deletion_policy
}

# 2. Three separate CI identities, so no single credential can do everything.
module "ci_identities" {
  source = "../modules/service_accounts"

  project_id = local.project_id
  accounts = {
    tf_plan = {
      account_id    = "tf-plan"
      display_name  = "Terraform plan (read-only)"
      description   = "Used by pull-request plans. Cannot change anything."
      project_roles = local.plan_roles
    }
    tf_apply = {
      account_id    = "tf-apply"
      display_name  = "Terraform apply"
      description   = "Applies the workload stack. Only reachable from the approved GitHub environment."
      project_roles = local.apply_roles
    }
    deployer = {
      account_id   = "gh-deployer"
      display_name = "Application deployer"
      description  = "Pushes the container image and deploys Cloud Run revisions. Resource-level grants live in the workload stack."
    }
  }
}

# 3. Keyless trust between GitHub and this project
module "github_wif" {
  source = "../modules/github_wif"

  project_id  = local.project_id
  github_repo = var.github_repo
}

# Plan identity: any workflow in the repo (including pull requests). Harmless because it is read-only.
resource "google_service_account_iam_member" "plan_from_repo" {
  service_account_id = "projects/${local.project_id}/serviceAccounts/${module.ci_identities.emails["tf_plan"]}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${module.github_wif.pool_name}/attribute.repository/${var.github_repo}"
}

# Apply and deploy identities: ONLY jobs running in the protected GitHub environment
# (which requires reviewer approval and is restricted to the main branch).
resource "google_service_account_iam_member" "apply_from_environment" {
  service_account_id = "projects/${local.project_id}/serviceAccounts/${module.ci_identities.emails["tf_apply"]}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${module.github_wif.pool_name}/subject/${local.environment_subject}"
}

resource "google_service_account_iam_member" "deployer_from_environment" {
  service_account_id = "projects/${local.project_id}/serviceAccounts/${module.ci_identities.emails["deployer"]}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${module.github_wif.pool_name}/subject/${local.environment_subject}"
}

# 4. Access to the shared state bucket (it lives in the admin project, outside this one).
resource "google_storage_bucket_iam_member" "state_bucket_reader" {
  for_each = {
    plan  = module.ci_identities.members["tf_plan"]
    apply = module.ci_identities.members["tf_apply"]
  }
  bucket = var.state_bucket_name
  role   = "roles/storage.legacyBucketReader" # storage.buckets.get + object listing
  member = each.value
}

resource "google_storage_bucket_iam_member" "state_plan_read" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectViewer" # plan reads state; it never writes (runs with -lock=false)
  member = module.ci_identities.members["tf_plan"]
}

resource "google_storage_bucket_iam_member" "state_apply_write" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectAdmin" # apply writes state and takes the lock object
  member = module.ci_identities.members["tf_apply"]
}
