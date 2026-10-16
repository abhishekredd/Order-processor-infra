environment = "prod"
region      = "asia-south1"

cpu           = "1"
memory        = "1Gi"
concurrency   = 80
min_instances = 1
max_instances = 20

cloud_run_deletion_protection = true
bucket_force_destroy          = false
input_retention_days          = 90
