################################################################################
# General
################################################################################

variable "region" {
  description = "AWS region"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener"
  type        = string
}

variable "vpn_cidr" {
  description = "CIDR block for VPN access to admin and observability services"
  type        = string
}

################################################################################
# RDS
################################################################################

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 50
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage in GiB for auto-scaling"
  type        = number
  default     = 500
}

################################################################################
# ElastiCache
################################################################################

variable "redis_node_type" {
  description = "ElastiCache node instance type"
  type        = string
  default     = "cache.r6g.large"
}

################################################################################
# ECS Services
################################################################################

variable "monolith_image" {
  description = "Full ECR image URI with tag for the .NET monolith"
  type        = string
}

variable "monolith_cpu" {
  description = "CPU units for monolith tasks"
  type        = number
  default     = 1024
}

variable "monolith_memory" {
  description = "Memory in MiB for monolith tasks"
  type        = number
  default     = 2048
}

variable "monolith_min_tasks" {
  description = "Minimum number of monolith tasks"
  type        = number
  default     = 2
}

variable "monolith_max_tasks" {
  description = "Maximum number of monolith tasks"
  type        = number
  default     = 2
}

variable "application_image" {
  description = "Full ECR image URI with tag for the Go application service"
  type        = string
}

variable "application_cpu" {
  description = "CPU units for application tasks"
  type        = number
  default     = 1024
}

variable "application_memory" {
  description = "Memory in MiB for application tasks"
  type        = number
  default     = 2048
}

variable "application_min_tasks" {
  description = "Minimum number of application tasks"
  type        = number
  default     = 2
}

variable "application_max_tasks" {
  description = "Maximum number of application tasks"
  type        = number
  default     = 3
}
