################################################################################
# Networking
################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

################################################################################
# ALB
################################################################################

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs_cluster.alb_dns_name
}

################################################################################
# RDS
################################################################################

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.endpoint
}

################################################################################
# ElastiCache
################################################################################

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.elasticache.endpoint
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = module.elasticache.connection_string
}

################################################################################
# SQS / SNS
################################################################################

output "sns_topic_arns" {
  description = "SNS topic ARNs by bounded context"
  value       = module.messaging.topic_arns
}

output "sqs_queue_urls" {
  description = "SQS queue URLs by bounded context"
  value       = module.messaging.queue_urls
}

################################################################################
# ECS Services
################################################################################

output "monolith_service_name" {
  description = "ECS monolith service name"
  value       = module.ecs_monolith.service_name
}

output "application_service_name" {
  description = "ECS application service name"
  value       = module.ecs_application.service_name
}

################################################################################
# Route 53
################################################################################

output "private_zone_id" {
  description = "Private hosted zone ID"
  value       = module.route53.zone_id
}
