terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }

  # Partial configuration; bucket and prefix are supplied at `terraform init` time.
  # The GCS backend provides state locking natively.
  backend "gcs" {}
}
