output "name" {
  description = "Bucket name."
  value       = google_storage_bucket.this.name
  depends_on  = [google_storage_bucket_iam_member.readers]
}

output "location" {
  description = "Bucket location."
  value       = google_storage_bucket.this.location
}
