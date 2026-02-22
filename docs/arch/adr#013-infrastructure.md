# ADR-013: Infrastructure as Code Strategy

## Status

Accepted

## Context

TrialFlow infrastructure spans two AWS accounts (Staging and Production per ADR-010), multiple components (ECS Fargate,
RDS, ElastiCache, SQS/SNS, API Gateway, AppConfig, Grafana Stack, ECR), and requires reproducible, version-controlled
infrastructure management.

Key requirements:

- Infrastructure must be reproducible across environments without duplication
- Secrets must never appear in code, git history, or environment variables passed directly
- Application configuration (non-secret) must be managed separately from infrastructure topology
- Infrastructure changes must go through the same review and approval process as application code

A key lesson from prior experience: storing application environment variables directly in Terraform infrastructure state
makes them inconvenient to manage and creates coupling between infrastructure lifecycle and application configuration
lifecycle.

## Decision

**Terraform** with reusable modules per component, separate environment configurations.

---

### Repository Structure

```
infrastructure/
├── modules/
│   ├── networking/        ← VPC, subnets, security groups, route tables
│   ├── ecs-service/       ← ECS Fargate service + task definition + auto scaling
│   ├── rds/               ← PostgreSQL instance, parameter groups, schema init
│   ├── elasticache/       ← Redis cluster configuration
│   ├── sqs-sns/           ← queues and topics per Bounded Context
│   ├── api-gateway/       ← Public Gateway routes and integrations
│   ├── codedeploy/        ← Blue/Green and Canary deployment configuration
│   ├── appconfig/         ← Feature flag environment and deployment strategy
│   ├── observability/     ← EC2 instance + Docker Compose for Grafana Stack
│   ├── ecr/               ← Container registry
│   ├── secrets/           ← AWS Secrets Manager entries (values injected, not stored)
│   └── route53/           ← Private Hosted Zone for Admin domain
│
└── environments/
    ├── staging/
    │   ├── main.tf         ← module composition
    │   ├── variables.tf    ← variable declarations
    │   └── terraform.tfvars ← staging-specific values (non-secret)
    └── prod/
        ├── main.tf
        ├── variables.tf
        └── terraform.tfvars
```

Modules are written once. Environments pass different variables — no infrastructure code duplication between Staging and
Production.

`terraform.tfvars.example` is committed to git with placeholder values. Actual `.tfvars` files are not committed —
non-secret values are stored in GitHub Secrets and injected by CI/CD pipeline.

---

### Variable Classification

Three distinct categories of configuration, each with its own storage and lifecycle:

**1. Infrastructure Variables (Terraform)**
Describe topology — instance sizes, replica counts, region, account IDs.
Stored in `terraform.tfvars`, injected by CI/CD from GitHub Secrets.

```hcl
# terraform.tfvars (not committed)
region          = "us-east-1"
rds_instance    = "db.r6g.large"
ecs_min_tasks   = 2
ecs_max_tasks   = 3
```

**2. Non-Secret Application Variables**
Runtime configuration that is not sensitive — log level, environment name, Auth0 domain, AppConfig endpoint.
Stored in ECS Task Definition `environment` block, managed by Terraform.

```hcl
environment = [
  { name = "APP_ENV",       value = "production" },
  { name = "LOG_LEVEL",     value = "info" },
  { name = "AUTH0_DOMAIN",  value = "trialflow.auth0.com" },
  { name = "APPCONFIG_APP", value = "trialflow-prod" }
]
```

**3. Secret Application Variables**
Sensitive runtime credentials — database passwords, Auth0 client secrets, Azure Key Vault access credentials, Redis
connection string.
Stored in **AWS Secrets Manager**. ECS Task Definition references ARNs — values are injected at container startup by
ECS, never stored in Terraform state or git.

```hcl
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-east-1:123456789:secret:trialflow/prod/db-password"
  },
  {
    name      = "AUTH0_CLIENT_SECRET"
    valueFrom = "arn:aws:secretsmanager:us-east-1:123456789:secret:trialflow/prod/auth0-secret"
  },
  {
    name      = "KV_CONNECTION_STRING"
    valueFrom = "arn:aws:secretsmanager:us-east-1:123456789:secret:trialflow/prod/redis-url"
  }
]
```

Secret values are set manually in AWS Secrets Manager on first deploy and rotated independently of infrastructure
changes.

---

### Secrets Module

The `secrets/` module manages Secrets Manager entries — it creates the secret resources (name, description, rotation
policy) but does **not** store values. Values are provided out-of-band.

```hcl
# modules/secrets/main.tf
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.env}/db-password"
  description = "PostgreSQL master password"
}
# Value set manually or via separate secure process — never in Terraform
```

---

### State Management

Per ADR-012, Terraform state is stored in S3 + DynamoDB per account:

```hcl
# environments/staging/main.tf
terraform {
  backend "s3" {
    bucket         = "trialflow-tfstate-staging"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "trialflow-tfstate-lock-staging"
    encrypt        = true
  }
}
```

State files are encrypted at rest. DynamoDB ensures only one `terraform apply` runs at a time.

---

### Module Composition Example

```hcl
# environments/prod/main.tf

module "networking" {
  source = "../../modules/networking"
  env    = "prod"
  region = var.region
}

module "rds" {
  source            = "../../modules/rds"
  env               = "prod"
  instance_class    = var.rds_instance
  vpc_id            = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
}

module "ecs_monolith" {
  source         = "../../modules/ecs-service"
  env            = "prod"
  service_name   = "monolith"
  image          = var.monolith_image
  min_tasks      = 2
  max_tasks      = 2
  deploy_strategy = "blue-green"
  # non-secret env vars inline
  environment    = local.monolith_env_vars
  # secret ARNs only
  secrets        = local.monolith_secrets
}

module "ecs_application" {
  source          = "../../modules/ecs-service"
  env             = "prod"
  service_name    = "application"
  image           = var.application_image
  min_tasks       = 2
  max_tasks       = 3
  deploy_strategy = "canary"
  scaling_metric  = "rps"
  scale_out_rps   = 1500
  scale_in_rps    = 1350
}
```

Same modules, different variables — Staging and Production are structurally identical, differ only in sizing and
configuration values.

## Consequences

**Positive:**

- Module reuse eliminates infrastructure duplication — changes to a module apply to both environments consistently
- Clear variable classification — infrastructure topology, non-secret config, and secrets never mixed
- Secrets never in git or Terraform state — AWS Secrets Manager is the only source of truth for sensitive values
- ECS task definition references secret ARNs — values injected at runtime, not build time
- Environments are structurally identical — reduces "works in staging, fails in prod" class of issues
- State locking prevents concurrent modifications

**Negative:**

- Secret values must be set manually in AWS Secrets Manager on first deploy and on rotation — not fully automated
- Module abstraction adds indirection — understanding what gets deployed requires reading both module and environment
  code
- `terraform.tfvars` not in git means environment setup requires documentation and onboarding process

## Alternatives Considered

**All variables in Terraform (including secrets)**
Rejected: Secrets in Terraform state means they appear in S3 state files and potentially in logs. Couples secret
rotation to infrastructure deployment cycle. This was the approach in a prior project and created operational pain.

**Environment variables directly in ECS without Secrets Manager**
Rejected: Secrets would appear in ECS task definition which is readable via AWS console and API. AWS Secrets Manager
provides access control, rotation, and audit logging for sensitive values.

**Separate repository for Terraform**
Rejected: Infrastructure and application code evolve together — keeping them in the same monorepo makes it easier to
coordinate changes, review PRs holistically, and maintain ADR documentation alongside both.

**Terragrunt for DRY environments**
Rejected for Phase 1: Adds tooling complexity. Terraform modules with separate environment directories are sufficient at
current scale. Can be introduced if number of environments grows.

## Related Decisions

- Implements infrastructure pipeline referenced in ADR-012 (CI/CD Pipeline Strategy)
- Implements secrets management referenced in ADR-005 (Authentication and Authorization)
- Covers infrastructure for all components defined in ADR-007, ADR-009, ADR-011