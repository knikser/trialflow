################################################################################
# VPC
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${var.env}-trialflow-vpc"
    Component = "networking"
  }
}

################################################################################
# Subnets
################################################################################

locals {
  public_subnet_names  = ["public-a", "public-b"]
  private_subnet_names = ["private-a", "private-b"]
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.env}-trialflow-${local.public_subnet_names[count.index]}"
    Component = "networking"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name      = "${var.env}-trialflow-${local.private_subnet_names[count.index]}"
    Component = "networking"
  }
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-igw"
    Component = "networking"
  }
}

################################################################################
# NAT Gateway (single, in public-a)
################################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name      = "${var.env}-trialflow-nat-eip"
    Component = "networking"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name      = "${var.env}-trialflow-nat"
    Component = "networking"
  }

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# Route Tables
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-public-rt"
    Component = "networking"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-private-rt"
    Component = "networking"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

################################################################################
# Route Table Associations
################################################################################

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

################################################################################
# Security Group: ALB
################################################################################

resource "aws_security_group" "alb" {
  name        = "${var.env}-trialflow-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-alb-sg"
    Component = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Security Group: ECS
################################################################################

resource "aws_security_group" "ecs" {
  name        = "${var.env}-trialflow-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-ecs-sg"
    Component = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "App port from ALB"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_vpn" {
  security_group_id = aws_security_group.ecs.id
  description       = "All traffic from VPN"
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpn_cidr
}

resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Security Group: RDS
################################################################################

resource "aws_security_group" "rds" {
  name        = "${var.env}-trialflow-rds-sg"
  description = "Security group for RDS PostgreSQL instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-rds-sg"
    Component = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from ECS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Security Group: Redis
################################################################################

resource "aws_security_group" "redis" {
  name        = "${var.env}-trialflow-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-redis-sg"
    Component = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from ECS"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

resource "aws_vpc_security_group_egress_rule" "redis_all" {
  security_group_id = aws_security_group.redis.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Security Group: Observability
################################################################################

resource "aws_security_group" "observability" {
  name        = "${var.env}-trialflow-observability-sg"
  description = "Security group for observability stack (Grafana, Prometheus, OTLP)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.env}-trialflow-observability-sg"
    Component = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "observability_otlp_from_ecs" {
  security_group_id            = aws_security_group.observability.id
  description                  = "OTLP gRPC from ECS"
  from_port                    = 4317
  to_port                      = 4317
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

resource "aws_vpc_security_group_ingress_rule" "observability_grafana_from_vpn" {
  security_group_id = aws_security_group.observability.id
  description       = "Grafana from VPN"
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpn_cidr
}

resource "aws_vpc_security_group_ingress_rule" "observability_prometheus_from_vpn" {
  security_group_id = aws_security_group.observability.id
  description       = "Prometheus from VPN"
  from_port         = 9090
  to_port           = 9090
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpn_cidr
}

resource "aws_vpc_security_group_egress_rule" "observability_all" {
  security_group_id = aws_security_group.observability.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
