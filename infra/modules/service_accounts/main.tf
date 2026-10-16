resource "google_service_account" "this" {
  for_each     = var.accounts
  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
}

locals {
  project_role_bindings = {
    for pair in flatten([
      for key, account in var.accounts : [
        for role in account.project_roles : {
          id   = "${key}/${role}"
          key  = key
          role = role
        }
      ]
    ]) : pair.id => pair
  }
}

resource "google_project_iam_member" "project_roles" {
  for_each = local.project_role_bindings
  project  = var.project_id
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.this[each.value.key].email}"
}
