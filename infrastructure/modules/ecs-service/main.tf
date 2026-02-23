locals {
  name_prefix = "${var.env}-trialflow-${var.service_name}"
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = {
    Name      = "${local.name_prefix}-logs"
    Component = "ecs"
  }
}

################################################################################
# IAM — Execution Role (ECR pull, Logs, Secrets Manager)
################################################################################

data "aws_iam_policy_document" "execution_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-execution"
  assume_role_policy = data.aws_iam_policy_document.execution_assume.json

  tags = {
    Name      = "${local.name_prefix}-execution"
    Component = "ecs"
  }
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid    = "ECRPull"
    effect = "Allow"

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetAuthorizationToken",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:trialflow/${var.env}/*",
    ]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "${local.name_prefix}-execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

################################################################################
# IAM — Task Role (SQS, SNS, AppConfig, additional policies)
################################################################################

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-task"
  assume_role_policy = data.aws_iam_policy_document.execution_assume.json

  tags = {
    Name      = "${local.name_prefix}-task"
    Component = "ecs"
  }
}

data "aws_iam_policy_document" "task" {
  statement {
    sid    = "SQSAccess"
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]

    resources = [
      "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.env}-trialflow-*",
    ]
  }

  statement {
    sid    = "SNSPublish"
    effect = "Allow"

    actions = [
      "sns:Publish",
    ]

    resources = [
      "arn:aws:sns:${var.region}:${data.aws_caller_identity.current.account_id}:${var.env}-trialflow-*",
    ]
  }

  statement {
    sid    = "AppConfigRead"
    effect = "Allow"

    actions = [
      "appconfig:StartConfigurationSession",
      "appconfig:GetLatestConfiguration",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${local.name_prefix}-task"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

resource "aws_iam_role_policy" "task_additional" {
  count = length(var.additional_task_role_policy_jsons)

  name   = "${local.name_prefix}-task-additional-${count.index}"
  role   = aws_iam_role.task.id
  policy = var.additional_task_role_policy_jsons[count.index]
}

################################################################################
# ECS Task Definition
################################################################################

resource "aws_ecs_task_definition" "this" {
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode(concat(
    [
      {
        name      = var.service_name
        image     = var.image
        cpu       = var.cpu - (var.enable_appconfig_sidecar ? 64 : 0)
        memory    = var.memory - (var.enable_appconfig_sidecar ? 128 : 0)
        essential = true

        portMappings = [
          {
            containerPort = var.container_port
            protocol      = "tcp"
          }
        ]

        environment = var.environment_variables
        secrets     = var.secrets

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this.name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = var.service_name
          }
        }

        healthCheck = {
          command     = ["CMD-SHELL", "wget -qO- http://localhost:${var.container_port}/health/live || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 60
        }

        dependsOn = var.enable_appconfig_sidecar ? [
          {
            containerName = "appconfig-agent"
            condition     = "START"
          }
        ] : []
      }
    ],
    var.enable_appconfig_sidecar ? [
      {
        name      = "appconfig-agent"
        image     = "public.ecr.aws/aws-appconfig/aws-appconfig-agent:2.x"
        cpu       = 64
        memory    = 128
        essential = true

        portMappings = [
          {
            containerPort = 2772
            protocol      = "tcp"
          }
        ]

        environment = [
          { name = "APPCONFIG_APPLICATION_ID", value = var.appconfig_application_id },
          { name = "APPCONFIG_ENVIRONMENT_ID", value = var.appconfig_environment_id },
          { name = "APPCONFIG_CONFIGURATION_PROFILES", value = var.appconfig_configuration_profile_id },
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this.name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = "appconfig-agent"
          }
        }
      }
    ] : []
  ))

  tags = {
    Name           = local.name_prefix
    Component      = "ecs"
    DeployStrategy = var.deploy_strategy
  }
}

################################################################################
# ALB Target Groups (Blue + Green for CodeDeploy)
################################################################################

resource "aws_lb_target_group" "blue" {
  name        = "${local.name_prefix}-blue"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name      = "${local.name_prefix}-blue"
    Component = "ecs"
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${local.name_prefix}-green"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name      = "${local.name_prefix}-green"
    Component = "ecs"
  }
}

################################################################################
# Cloud Map Service Discovery
################################################################################

resource "aws_service_discovery_service" "this" {
  name = var.service_name

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name      = "${local.name_prefix}-discovery"
    Component = "ecs"
  }
}

################################################################################
# ECS Service
################################################################################

resource "aws_ecs_service" "this" {
  name            = local.name_prefix
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.min_tasks
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  tags = {
    Name           = local.name_prefix
    Component      = "ecs"
    DeployStrategy = var.deploy_strategy
  }
}

################################################################################
# Auto-scaling (conditional)
################################################################################

resource "aws_appautoscaling_target" "this" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.max_tasks
  min_capacity       = var.min_tasks
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# --- Scale Out ---

resource "aws_appautoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.name_prefix}-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.scale_out_cooldown
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 1
      metric_interval_lower_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name          = "${local.name_prefix}-scale-out"
  alarm_description   = "Scale out when ALB request count per target exceeds ${var.scale_out_threshold}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 30
  statistic           = "Average"
  threshold           = var.scale_out_threshold

  dimensions = {
    TargetGroup = aws_lb_target_group.blue.arn_suffix
  }

  alarm_actions = [aws_appautoscaling_policy.scale_out[0].arn]

  tags = {
    Name      = "${local.name_prefix}-scale-out"
    Component = "ecs"
  }
}

# --- Scale In ---

resource "aws_appautoscaling_policy" "scale_in" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.name_prefix}-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.scale_in_cooldown
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = -1
      metric_interval_upper_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_in" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name          = "${local.name_prefix}-scale-in"
  alarm_description   = "Scale in when ALB request count per target drops below ${var.scale_in_threshold}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 30
  statistic           = "Average"
  threshold           = var.scale_in_threshold

  dimensions = {
    TargetGroup = aws_lb_target_group.blue.arn_suffix
  }

  alarm_actions = [aws_appautoscaling_policy.scale_in[0].arn]

  tags = {
    Name      = "${local.name_prefix}-scale-in"
    Component = "ecs"
  }
}
