# Non-secret, environment-specific settings. Billing account / org / repo go in terraform.tfvars (git-ignored).
environment             = "dev"
project_id_prefix       = "retailhub-compat-dev"
project_name            = "RetailHub Compat dev"
region                  = "asia-south1"
github_environment      = "dev"
project_deletion_policy = "DELETE" # dev can be destroyed; use PREVENT elsewhere
