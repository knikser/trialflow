output "zone_id" {
  description = "ID of the private hosted zone"
  value       = aws_route53_zone.private.zone_id
}

output "zone_name" {
  description = "Name of the private hosted zone"
  value       = aws_route53_zone.private.name
}
