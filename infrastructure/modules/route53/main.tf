################################################################################
# Private Hosted Zone
################################################################################

resource "aws_route53_zone" "private" {
  name = var.zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = {
    Name      = "${var.env}-trialflow-dns"
    Component = "route53"
  }
}

################################################################################
# DNS Records
################################################################################

resource "aws_route53_record" "this" {
  for_each = { for r in var.records : r.name => r }

  zone_id = aws_route53_zone.private.zone_id
  name    = each.value.name
  type    = each.value.type

  # Simple records: use ttl + records when alias is not set
  ttl     = each.value.alias == null ? each.value.ttl : null
  records = each.value.alias == null ? each.value.records : null

  # Alias records: use dynamic block when alias is set
  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []

    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }
}
