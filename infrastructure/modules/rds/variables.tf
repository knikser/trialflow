variable "env" {
  description = "Environment name (e.g. staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID to attach to the RDS instance"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.medium for staging, db.r6g.large for prod)"
  type        = string
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage in GiB for storage auto-scaling"
  type        = number
  default     = 100
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
}

variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "trialflow"
}

variable "master_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "trialflow_admin"
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the instance (true for staging, false for prod)"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Enable encryption at rest for the RDS instance"
  type        = bool
  default     = true
}
