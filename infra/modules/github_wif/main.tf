# Keyless auth for GitHub Actions. The provider only trusts tokens issued for ONE repository;
# which workflow/environment may use which service account is decided by the service-account
# bindings (see foundation/main.tf), not here.
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  #checkov:skip=CKV_GCP_125:The provider pins the exact repository. This check only accepts one exact `assertion.sub`, but plan runs (pull_request) and apply runs (environment) legitimately have different subjects. The strict per-subject rule is enforced on the service-account bindings (foundation/main.tf), and apply/deploy accept only repo:OWNER/REPO:environment:<env>.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
