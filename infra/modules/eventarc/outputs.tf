output "trigger_name" {
  description = "Trigger name."
  value       = google_eventarc_trigger.on_upload.name
}
