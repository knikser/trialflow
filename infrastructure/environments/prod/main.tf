locals {
  env = "prod"

  monolith_env_vars = [
    { name = "APP_ENV", value = local.env },
    { name = "LOG_LEVEL", value = "info" },
    { name = "AUTH0_DOMAIN", value = "trialflow.auth0.com" },
    { name = "DB_HOST", value = module.rds.address },
    { name = "DB_PORT", value = tostring(module.rds.port) },
    { name = "DB_NAME", value = module.rds.db_name },
    { name = "DB_USER", value = module.rds.master_username },
    { name = "REDIS_ENDPOINT", value = module.elasticache.endpoint },
    { name = "REDIS_PORT", value = tostring(module.elasticache.port) },
  ]

  application_env_vars = [
    { name = "APP_ENV", value = local.env },
    { name = "LOG_LEVEL", value = "info" },
    { name = "AUTH0_DOMAIN", value = "trialflow.auth0.com" },
    { name = "DB_HOST", value = module.rds.address },
    { name = "DB_PORT", value = tostring(module.rds.port) },
    { name = "DB_NAME", value = module.rds.db_name },
    { name = "DB_USER", value = module.rds.master_username },
    { name = "REDIS_ENDPOINT", value = module.elasticache.endpoint },
    { name = "REDIS_PORT", value = tostring(module.elasticache.port) },
  ]

  service_secrets = [
    { name = "DB_PASSWORD", valueFrom = module.secrets.secret_arns["db-password"] },
    { name = "AUTH0_CLIENT_SECRET", valueFrom = module.secrets.secret_arns["auth0-client-secret"] },
    { name = "AZURE_KEYVAULT_CREDENTIALS", valueFrom = module.secrets.secret_arns["azure-keyvault-credentials"] },
    { name = "KV_CONNECTION_STRING", valueFrom = module.secrets.secret_arns["redis-url"] },
  ]
}

################################################################################
# Networking
################################################################################

module "networking" {
  source = "../../modules/networking"

  env      = local.env
  region   = var.region
  vpn_cidr = var.vpn_cidr
}

################################################################################
# ECS Cluster & ALB
################################################################################

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  env                        = local.env
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  private_subnet_ids         = module.networking.private_subnet_ids
  alb_security_group_id      = module.networking.alb_security_group_id
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = true
}

################################################################################
# RDS (PostgreSQL)
################################################################################

module "rds" {
  source = "../../modules/rds"

  env                   = local.env
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  security_group_id     = module.networking.rds_security_group_id
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = true
  deletion_protection   = true
  skip_final_snapshot   = false
  backup_retention_period = 14
}

################################################################################
# ElastiCache (Redis)
################################################################################

module "elasticache" {
  source = "../../modules/elasticache"

  env               = local.env
  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id = module.networking.redis_security_group_id
  node_type         = var.redis_node_type
}

################################################################################
# SQS / SNS (Message Bus)
################################################################################

module "messaging" {
  source = "../../modules/sqs-sns"

  env = local.env
}

################################################################################
# ECR — not created in prod; prod pulls from staging ECR (ADR-012)
################################################################################

################################################################################
# AppConfig (Feature Flags)
################################################################################

module "appconfig" {
  source = "../../modules/appconfig"

  env = local.env
}

################################################################################
# Secrets Manager
################################################################################

module "secrets" {
  source = "../../modules/secrets"

  env = local.env
}

################################################################################
# Route 53 (Private DNS)
################################################################################

module "route53" {
  source = "../../modules/route53"

  env    = local.env
  vpc_id = module.networking.vpc_id
}

################################################################################
# ECS Service: .NET Monolith (Blue/Green)
################################################################################

module "ecs_monolith" {
  source = "../../modules/ecs-service"

  env             = local.env
  region          = var.region
  cluster_id      = module.ecs_cluster.cluster_id
  cluster_name    = module.ecs_cluster.cluster_name
  service_name    = "monolith"
  image           = var.monolith_image
  cpu             = var.monolith_cpu
  memory          = var.monolith_memory
  min_tasks       = var.monolith_min_tasks
  max_tasks       = var.monolith_max_tasks
  deploy_strategy = "blue-green"

  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id
  alb_listener_arn      = module.ecs_cluster.alb_listener_https_arn

  environment_variables = local.monolith_env_vars
  secrets               = local.service_secrets

  appconfig_application_id             = module.appconfig.application_id
  appconfig_environment_id             = module.appconfig.environment_id
  appconfig_configuration_profile_id   = module.appconfig.configuration_profile_id

  service_discovery_namespace_id = module.ecs_cluster.service_discovery_namespace_id

  additional_task_role_policy_jsons = [module.messaging.task_policy_json]

  enable_autoscaling = false
}

################################################################################
# ECS Service: Go Application (Canary)
################################################################################

module "ecs_application" {
  source = "../../modules/ecs-service"

  env             = local.env
  region          = var.region
  cluster_id      = module.ecs_cluster.cluster_id
  cluster_name    = module.ecs_cluster.cluster_name
  service_name    = "application"
  image           = var.application_image
  cpu             = var.application_cpu
  memory          = var.application_memory
  min_tasks       = var.application_min_tasks
  max_tasks       = var.application_max_tasks
  deploy_strategy = "canary"

  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id
  alb_listener_arn      = module.ecs_cluster.alb_listener_https_arn

  environment_variables = local.application_env_vars
  secrets               = local.service_secrets

  appconfig_application_id             = module.appconfig.application_id
  appconfig_environment_id             = module.appconfig.environment_id
  appconfig_configuration_profile_id   = module.appconfig.configuration_profile_id

  service_discovery_namespace_id = module.ecs_cluster.service_discovery_namespace_id

  additional_task_role_policy_jsons = [module.messaging.task_policy_json]

  enable_autoscaling    = true
  scale_out_threshold   = 1500
  scale_in_threshold    = 1350
}
