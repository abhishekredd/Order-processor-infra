output "output_topic_name" {
  description = "Output topic name."
  value       = google_pubsub_topic.output.name
  depends_on  = [google_pubsub_topic_iam_member.output_publishers]
}

output "dlq_topic_name" {
  description = "Dead-letter topic name."
  value       = google_pubsub_topic.dlq.name
  depends_on  = [google_pubsub_topic_iam_member.dlq_publishers, google_pubsub_topic_iam_member.dlq_agent_publisher]
}

output "output_subscription" {
  description = "Output subscription name (null if subscriptions are disabled)."
  value       = try(google_pubsub_subscription.output[0].name, null)
}

output "dlq_subscription" {
  description = "Dead-letter subscription name (null if subscriptions are disabled)."
  value       = try(google_pubsub_subscription.dlq[0].name, null)
}
