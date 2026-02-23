################################################################################
# Subnet Group
################################################################################

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.env}-trialflow-redis"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name      = "${var.env}-trialflow-redis-subnet-group"
    Component = "elasticache"
  }
}

################################################################################
# Parameter Group — disable persistence (cache-only, PostgreSQL is source of truth)
################################################################################

resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.env}-trialflow-redis"
  family = var.parameter_group_family

  parameter {
    name  = "appendonly"
    value = "no"
  }

  parameter {
    name  = "save"
    value = ""
  }

  tags = {
    Name      = "${var.env}-trialflow-redis-params"
    Component = "elasticache"
  }
}

################################################################################
# Redis Cluster
################################################################################

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.env}-trialflow-redis"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.this.name
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.security_group_id]

  tags = {
    Name      = "${var.env}-trialflow-redis"
    Component = "elasticache"
  }
}
