output "state_bucket_name" {
  description = "Put this in each environment's backend.hcl."
  value       = google_storage_bucket.tfstate.name
}
