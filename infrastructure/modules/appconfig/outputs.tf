output "application_id" {
  description = "AppConfig application ID"
  value       = aws_appconfig_application.this.id
}

output "environment_id" {
  description = "AppConfig environment ID"
  value       = aws_appconfig_environment.this.environment_id
}

output "configuration_profile_id" {
  description = "AppConfig configuration profile ID"
  value       = aws_appconfig_configuration_profile.this.configuration_profile_id
}

output "deployment_strategy_id" {
  description = "AppConfig deployment strategy ID"
  value       = aws_appconfig_deployment_strategy.this.id
}
