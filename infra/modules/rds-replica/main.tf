# Provider configuration for standby region
provider "aws" {
  alias  = "standby"
  region = var.region
}

locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
      Module    = "rds-replica"
    }
  )
}

# Security group for RDS replica
resource "aws_security_group" "rds_replica" {
  provider    = aws.standby
  name_prefix = "${var.db_identifier}-replica-sg-"
  description = "Security group for RDS replica ${var.db_identifier}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Allow PostgreSQL from Lambda security groups"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.db_identifier}-replica-sg"
  })
}

# RDS read replica in standby region
resource "aws_db_instance" "replica" {
  provider               = aws.standby
  identifier             = "${var.db_identifier}-replica"
  replicate_source_db    = var.source_db_arn
  instance_class         = var.instance_class
  vpc_security_group_ids = [aws_security_group.rds_replica.id]

  auto_minor_version_upgrade = true
  backup_retention_period    = var.backup_retention_period
  multi_az                   = false # Cost optimization for replica
  storage_encrypted          = true

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn

  deletion_protection = true # Prevent accidental deletion

  lifecycle {
    prevent_destroy = true # Protect against accidental destruction
  }

  tags = merge(local.common_tags, {
    Name = "${var.db_identifier}-replica"
  })

  depends_on = [aws_security_group.rds_replica]
}

# CloudWatch alarms for replica monitoring
resource "aws_cloudwatch_metric_alarm" "replica_lag" {
  provider            = aws.standby
  alarm_name          = "${var.db_identifier}-replica-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "ReplicaLag"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "300" # 5 minutes
  alarm_description   = "Replica lag is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.replica.id
  }
}

# CloudWatch dashboard for replica monitoring
resource "aws_cloudwatch_dashboard" "replica" {
  provider       = aws.standby
  dashboard_name = "${var.db_identifier}-replica-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReplicaLag", "DBInstanceIdentifier", aws_db_instance.replica.id],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.replica.id],
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", aws_db_instance.replica.id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Replica Metrics"
        }
      }
    ]
  })
}