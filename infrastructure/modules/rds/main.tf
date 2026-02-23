################################################################################
# DB Subnet Group
################################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-trialflow-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name      = "${var.env}-trialflow-db-subnet-group"
    Component = "rds"
  }
}

################################################################################
# Parameter Group
################################################################################

resource "aws_db_parameter_group" "postgres16" {
  name   = "${var.env}-trialflow-postgres16"
  family = "postgres16"

  tags = {
    Name      = "${var.env}-trialflow-postgres16"
    Component = "rds"
  }

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# RDS Instance
################################################################################

resource "aws_db_instance" "main" {
  identifier = "${var.env}-trialflow-db"

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Instance
  instance_class = var.instance_class
  multi_az       = var.multi_az

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  # Database
  db_name  = var.db_name
  username = var.master_username
  port     = 5432

  # Password managed by RDS via Secrets Manager (not stored in Terraform state)
  manage_master_user_password = true

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres16.name

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"

  # Maintenance
  maintenance_window = "Mon:04:30-Mon:05:30"

  # Deletion / snapshot
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.env}-trialflow-db-final"

  # Monitoring
  performance_insights_enabled = true

  tags = {
    Name      = "${var.env}-trialflow-db"
    Component = "rds"
  }
}
