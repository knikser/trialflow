variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "secrets" {
  description = "List of secrets to create in AWS Secrets Manager"
  type = list(object({
    name        = string
    description = string
  }))
  default = [
    {
      name        = "db-password"
      description = "PostgreSQL master password"
    },
    {
      name        = "auth0-client-secret"
      description = "Auth0 client secret"
    },
    {
      name        = "azure-keyvault-credentials"
      description = "Azure Key Vault access credentials for PHI encryption"
    },
    {
      name        = "redis-url"
      description = "ElastiCache Redis connection string"
    },
  ]
}

variable "recovery_window_in_days" {
  description = "Number of days before a secret can be fully deleted"
  type        = number
  default     = 30
}
