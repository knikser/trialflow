output "endpoint" {
  description = "RDS instance endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the default database"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Master username for the RDS instance"
  value       = aws_db_instance.main.username
}

output "db_instance_id" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.main.id
}
