locals {
  context_set = toset(var.contexts)
}

# ------------------------------------------------------------------------------
# SNS Topics
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "events" {
  for_each = local.context_set

  name = "${var.env}-trialflow-${each.key}-events"
}

# ------------------------------------------------------------------------------
# SQS Dead Letter Queues
# ------------------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  for_each = local.context_set

  name                      = "${var.env}-trialflow-${each.key}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
}

# ------------------------------------------------------------------------------
# SQS Queues
# ------------------------------------------------------------------------------

resource "aws_sqs_queue" "queue" {
  for_each = local.context_set

  name                       = "${var.env}-trialflow-${each.key}-queue"
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = var.max_receive_count
  })
}

# ------------------------------------------------------------------------------
# SQS Queue Policies — allow the SNS topic to send messages to the queue
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "sqs_allow_sns" {
  for_each = local.context_set

  statement {
    sid    = "AllowSNSPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.queue[each.key].arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.events[each.key].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "queue" {
  for_each = local.context_set

  queue_url = aws_sqs_queue.queue[each.key].id
  policy    = data.aws_iam_policy_document.sqs_allow_sns[each.key].json
}

# ------------------------------------------------------------------------------
# SNS -> SQS Subscriptions
# ------------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "sqs" {
  for_each = local.context_set

  topic_arn = aws_sns_topic.events[each.key].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue[each.key].arn

  raw_message_delivery = true
}

# ------------------------------------------------------------------------------
# IAM Policy Document for ECS Task Role
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "task_policy" {
  statement {
    sid    = "AllowSQSActions"
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]

    resources = concat(
      [for ctx in local.context_set : aws_sqs_queue.queue[ctx].arn],
      [for ctx in local.context_set : aws_sqs_queue.dlq[ctx].arn],
    )
  }

  statement {
    sid    = "AllowSNSPublish"
    effect = "Allow"

    actions = [
      "sns:Publish",
    ]

    resources = [for ctx in local.context_set : aws_sns_topic.events[ctx].arn]
  }
}
