output "secret_arns" {
  description = "Map of secret name to ARN"
  value       = { for name, secret in aws_secretsmanager_secret.this : name => secret.arn }
}
