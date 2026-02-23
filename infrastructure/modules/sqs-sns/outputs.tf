output "topic_arns" {
  description = "Map of bounded context to SNS topic ARN"
  value       = { for ctx, topic in aws_sns_topic.events : ctx => topic.arn }
}

output "queue_urls" {
  description = "Map of bounded context to SQS queue URL"
  value       = { for ctx, queue in aws_sqs_queue.queue : ctx => queue.id }
}

output "queue_arns" {
  description = "Map of bounded context to SQS queue ARN"
  value       = { for ctx, queue in aws_sqs_queue.queue : ctx => queue.arn }
}

output "dlq_urls" {
  description = "Map of bounded context to SQS DLQ URL"
  value       = { for ctx, dlq in aws_sqs_queue.dlq : ctx => dlq.id }
}

output "dlq_arns" {
  description = "Map of bounded context to SQS DLQ ARN"
  value       = { for ctx, dlq in aws_sqs_queue.dlq : ctx => dlq.arn }
}

output "task_policy_json" {
  description = "IAM policy document JSON granting SQS and SNS permissions for ECS task roles"
  value       = data.aws_iam_policy_document.task_policy.json
}
