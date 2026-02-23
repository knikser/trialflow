variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "contexts" {
  description = "List of bounded contexts to create SQS/SNS resources for"
  type        = list(string)
  default     = ["identity", "organization", "study", "application", "research-site", "notification"]
}

variable "max_receive_count" {
  description = "Number of times a message is received before being sent to the DLQ"
  type        = number
  default     = 5
}

variable "message_retention_seconds" {
  description = "Number of seconds to retain messages in the main queue (default 14 days)"
  type        = number
  default     = 1209600
}

variable "dlq_message_retention_seconds" {
  description = "Number of seconds to retain messages in the DLQ (default 14 days)"
  type        = number
  default     = 1209600
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for the main queue in seconds"
  type        = number
  default     = 30
}
