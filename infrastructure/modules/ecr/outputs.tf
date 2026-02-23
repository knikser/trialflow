output "repository_urls" {
  description = "Map of repository name to repository URL"
  value       = { for key, repo in aws_ecr_repository.this : key => repo.repository_url }
}

output "repository_arns" {
  description = "Map of repository name to repository ARN"
  value       = { for key, repo in aws_ecr_repository.this : key => repo.arn }
}
