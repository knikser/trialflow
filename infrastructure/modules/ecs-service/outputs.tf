output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}

output "target_group_blue_arn" {
  description = "Blue target group ARN (primary)"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_blue_name" {
  description = "Blue target group name"
  value       = aws_lb_target_group.blue.name
}

output "target_group_green_arn" {
  description = "Green target group ARN (secondary, for CodeDeploy)"
  value       = aws_lb_target_group.green.arn
}

output "target_group_green_name" {
  description = "Green target group name"
  value       = aws_lb_target_group.green.name
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "ECS execution role ARN"
  value       = aws_iam_role.execution.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.this.name
}

output "service_discovery_service_arn" {
  description = "Cloud Map service discovery service ARN"
  value       = aws_service_discovery_service.this.arn
}
