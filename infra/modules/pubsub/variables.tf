variable "project_id" {
  description = "Project that owns the topics."
  type        = string
}

variable "output_topic_name" {
  description = "Topic for valid, contract-compliant CloudEvents."
  type        = string
}

variable "dlq_topic_name" {
  description = "Dead-letter topic. Receives (a) records the processor rejects and (b) messages Pub/Sub could not deliver to a subscriber."
  type        = string
}

variable "publishers" {
  description = "Map of static key -> IAM member granted roles/pubsub.publisher on both topics."
  type        = map(string)
  default     = {}
}

variable "create_subscriptions" {
  description = "Create the output subscription (with dead-letter policy) and the DLQ subscription. Without a subscription, messages published to a topic are dropped."
  type        = bool
  default     = true
}

variable "max_delivery_attempts" {
  description = "Delivery attempts on the output subscription before a message is forwarded to the dead-letter topic (5-100)."
  type        = number
  default     = 5
  validation {
    condition     = var.max_delivery_attempts >= 5 && var.max_delivery_attempts <= 100
    error_message = "Pub/Sub requires 5-100 delivery attempts."
  }
}

variable "message_retention_duration" {
  description = "How long subscriptions retain unacknowledged messages."
  type        = string
  default     = "86400s"
}

variable "labels" {
  description = "Labels for topics and subscriptions."
  type        = map(string)
  default     = {}
}
