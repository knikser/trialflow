locals {
  secrets_map = { for s in var.secrets : s.name => s }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets_map

  name                    = "trialflow/${var.env}/${each.key}"
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Environment = var.env
    Component   = "secrets"
  }
}
