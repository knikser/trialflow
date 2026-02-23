################################################################################
# General
################################################################################

variable "env" {
  description = "Environment name (e.g. staging, production)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

################################################################################
# ECS Cluster
################################################################################

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

################################################################################
# Service
################################################################################

variable "service_name" {
  description = "Service name — 'monolith' or 'application'"
  type        = string
}

variable "image" {
  description = "Full ECR image URI with tag"
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Task-level CPU units"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Task-level memory in MiB"
  type        = number
  default     = 1024
}

variable "min_tasks" {
  description = "Minimum (and desired) number of tasks"
  type        = number
}

variable "max_tasks" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
}

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/health/ready"
}

variable "deploy_strategy" {
  description = "Deployment strategy label — 'blue-green' or 'canary' (used for naming/tagging)"
  type        = string
}

################################################################################
# Networking
################################################################################

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "alb_listener_arn" {
  description = "ALB listener ARN to register target groups with"
  type        = string
}

################################################################################
# Container Configuration
################################################################################

variable "environment_variables" {
  description = "Environment variables for the application container"
  type        = list(object({ name = string, value = string }))
  default     = []
}

variable "secrets" {
  description = "Secrets from Secrets Manager for the application container"
  type        = list(object({ name = string, valueFrom = string }))
  default     = []
}

################################################################################
# AppConfig Sidecar
################################################################################

variable "enable_appconfig_sidecar" {
  description = "Whether to run the AppConfig agent sidecar"
  type        = bool
  default     = true
}

variable "appconfig_application_id" {
  description = "AppConfig application ID"
  type        = string
  default     = ""
}

variable "appconfig_environment_id" {
  description = "AppConfig environment ID"
  type        = string
  default     = ""
}

variable "appconfig_configuration_profile_id" {
  description = "AppConfig configuration profile ID"
  type        = string
  default     = ""
}

################################################################################
# Service Discovery
################################################################################

variable "service_discovery_namespace_id" {
  description = "Cloud Map namespace ID for service discovery"
  type        = string
}

################################################################################
# IAM
################################################################################

variable "additional_task_role_policy_jsons" {
  description = "Additional IAM policy JSON documents to attach to the task role"
  type        = list(string)
  default     = []
}

################################################################################
# Auto-scaling
################################################################################

variable "enable_autoscaling" {
  description = "Whether to enable auto-scaling for this service"
  type        = bool
  default     = false
}

variable "scale_out_threshold" {
  description = "ALB request count per target to trigger scale out"
  type        = number
  default     = 1500
}

variable "scale_in_threshold" {
  description = "ALB request count per target to trigger scale in"
  type        = number
  default     = 1350
}

variable "scale_out_cooldown" {
  description = "Cooldown in seconds after a scale-out action"
  type        = number
  default     = 60
}

variable "scale_in_cooldown" {
  description = "Cooldown in seconds after a scale-in action"
  type        = number
  default     = 300
}
