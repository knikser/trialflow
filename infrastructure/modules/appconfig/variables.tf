variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "application_name" {
  description = "AppConfig application base name"
  type        = string
  default     = "trialflow"
}

variable "deployment_strategy_percentage" {
  description = "Percentage of targets to deploy per step"
  type        = number
  default     = 10
}

variable "deployment_strategy_interval" {
  description = "Minutes between each deployment step"
  type        = number
  default     = 1
}

variable "deployment_strategy_final_bake" {
  description = "Minutes to monitor after deployment completes"
  type        = number
  default     = 5
}
