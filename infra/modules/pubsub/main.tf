data "google_project" "this" {
  project_id = var.project_id
}

locals {
  # Pub/Sub's own service agent performs dead-letter forwarding on our behalf.
  pubsub_service_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic" "output" {
  #checkov:skip=CKV_GCP_83:Google-managed encryption is accepted; customer-managed keys need a KMS setup that is out of scope.
  project = var.project_id
  name    = var.output_topic_name
  labels  = var.labels
}

resource "google_pubsub_topic" "dlq" {
  #checkov:skip=CKV_GCP_83:Google-managed encryption is accepted; customer-managed keys need a KMS setup that is out of scope.
  project = var.project_id
  name    = var.dlq_topic_name
  labels  = var.labels
}

resource "google_pubsub_subscription" "output" {
  count                      = var.create_subscriptions ? 1 : 0
  project                    = var.project_id
  name                       = "${var.output_topic_name}-verify"
  topic                      = google_pubsub_topic.output.id
  ack_deadline_seconds       = 20
  message_retention_duration = var.message_retention_duration
  labels                     = var.labels

  # Messages that keep failing delivery are forwarded to the dead-letter topic.
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  expiration_policy {
    ttl = "" # never expire
  }
}

# The DLQ needs its own subscription, otherwise dead-lettered messages are dropped.
resource "google_pubsub_subscription" "dlq" {
  count                      = var.create_subscriptions ? 1 : 0
  project                    = var.project_id
  name                       = "${var.dlq_topic_name}-verify"
  topic                      = google_pubsub_topic.dlq.id
  ack_deadline_seconds       = 20
  message_retention_duration = var.message_retention_duration
  labels                     = var.labels

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_topic_iam_member" "output_publishers" {
  for_each = var.publishers
  project  = var.project_id
  topic    = google_pubsub_topic.output.name
  role     = "roles/pubsub.publisher"
  member   = each.value
}

resource "google_pubsub_topic_iam_member" "dlq_publishers" {
  for_each = var.publishers
  project  = var.project_id
  topic    = google_pubsub_topic.dlq.name
  role     = "roles/pubsub.publisher"
  member   = each.value
}

# Dead-letter delivery: the Pub/Sub service agent must publish to the DLQ topic ...
resource "google_pubsub_topic_iam_member" "dlq_agent_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

# ... and acknowledge (remove) the failed message from the source subscription.
resource "google_pubsub_subscription_iam_member" "output_agent_subscriber" {
  count        = var.create_subscriptions ? 1 : 0
  project      = var.project_id
  subscription = google_pubsub_subscription.output[0].name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_service_agent
}
