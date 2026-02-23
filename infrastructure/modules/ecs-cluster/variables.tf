variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Base name for the ECS cluster"
  type        = string
  default     = "trialflow"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets for ALB placement"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for ECS tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB (recommended for prod)"
  type        = bool
  default     = false
}
