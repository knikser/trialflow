variable "env" {
  description = "Environment name (e.g. staging, production)"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository base names"
  type        = list(string)
  default     = ["trialflow-monolith", "trialflow-application"]
}

variable "production_account_id" {
  description = "AWS account ID to grant cross-account pull access. Leave empty to skip."
  type        = string
  default     = ""
}

variable "image_retention_count" {
  description = "Number of tagged images to retain per repository"
  type        = number
  default     = 20
}
