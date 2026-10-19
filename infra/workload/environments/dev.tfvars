# Non-secret, environment-specific settings. project_id is passed on the command line / by CI.
environment = "dev"
region      = "asia-south1"

# Cloud Run sizing
cpu           = "1"
memory        = "1Gi"
concurrency   = 80
min_instances = 0
max_instances = 2

# dev is disposable
cloud_run_deletion_protection = false
bucket_force_destroy          = true
