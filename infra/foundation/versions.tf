terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    time   = { source = "hashicorp/time", version = "~> 0.12" }
  }

  # Partial configuration; bucket and prefix are supplied at `terraform init` time.
  backend "gcs" {}
}
