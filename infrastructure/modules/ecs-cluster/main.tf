################################################################################
# ECS Cluster
################################################################################

resource "aws_ecs_cluster" "main" {
  name = "${var.env}-${var.cluster_name}"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = {
    Name      = "${var.env}-${var.cluster_name}"
    Component = "ecs-cluster"
  }
}

################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "main" {
  name               = "${var.env}-trialflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name      = "${var.env}-trialflow-alb"
    Component = "ecs-cluster"
  }
}

################################################################################
# ALB Listeners
################################################################################

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = {
    Name      = "${var.env}-trialflow-https"
    Component = "ecs-cluster"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name      = "${var.env}-trialflow-http-redirect"
    Component = "ecs-cluster"
  }
}

################################################################################
# Cloud Map Service Discovery Namespace
################################################################################

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "local"
  description = "Private DNS namespace for ECS service discovery"
  vpc         = var.vpc_id

  tags = {
    Name      = "${var.env}-trialflow-service-discovery"
    Component = "ecs-cluster"
  }
}
