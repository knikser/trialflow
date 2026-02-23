variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to associate with the private hosted zone"
  type        = string
}

variable "zone_name" {
  description = "Domain name for the private hosted zone"
  type        = string
  default     = "trialflow.internal"
}

variable "records" {
  description = "List of DNS records to create in the hosted zone"
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string), [])
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = bool
    }))
  }))
  default = []
}
