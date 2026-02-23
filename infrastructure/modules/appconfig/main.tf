locals {
  prefix = "${var.env}-${var.application_name}"
}

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
resource "aws_appconfig_application" "this" {
  name        = "${local.prefix}-app"
  description = "TrialFlow feature-flag application (${var.env})"

  tags = {
    Environment = var.env
    Component   = "appconfig"
  }
}

# ---------------------------------------------------------------------------
# Environment (one per env)
# ---------------------------------------------------------------------------
resource "aws_appconfig_environment" "this" {
  name           = "${local.prefix}-env"
  description    = "TrialFlow ${var.env} environment"
  application_id = aws_appconfig_application.this.id

  tags = {
    Environment = var.env
    Component   = "appconfig"
  }
}

# ---------------------------------------------------------------------------
# Configuration Profile (freeform JSON — flag content managed outside TF)
# ---------------------------------------------------------------------------
resource "aws_appconfig_configuration_profile" "this" {
  application_id = aws_appconfig_application.this.id
  name           = "${local.prefix}-feature-flags"
  description    = "Freeform JSON configuration profile for feature flags"
  location_uri   = "hosted"

  tags = {
    Environment = var.env
    Component   = "appconfig"
  }
}

# ---------------------------------------------------------------------------
# Deployment Strategy — linear rollout
# ---------------------------------------------------------------------------
resource "aws_appconfig_deployment_strategy" "this" {
  name                           = "${local.prefix}-linear"
  description                    = "Linear ${var.deployment_strategy_percentage}% per step, ${var.deployment_strategy_interval}-min interval, ${var.deployment_strategy_final_bake}-min bake"
  deployment_duration_in_minutes = ceil(100 / var.deployment_strategy_percentage) * var.deployment_strategy_interval
  growth_factor                  = var.deployment_strategy_percentage
  growth_type                    = "LINEAR"
  final_bake_time_in_minutes     = var.deployment_strategy_final_bake
  replicate_to                   = "NONE"

  tags = {
    Environment = var.env
    Component   = "appconfig"
  }
}
