output "trigger_name" {
  description = "Trigger name."
  # The API returns the short name right after create and the full resource path on later reads.
  # basename() gives the short name in both cases, so repeated plans see no change.
  value = basename(google_eventarc_trigger.on_upload.name)
}
