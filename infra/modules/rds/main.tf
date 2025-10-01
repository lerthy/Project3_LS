# Default VPC to host RDS security group
data "aws_vpc" "default" {
  default = true
}

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_security_group" "rds_ingress" {
  name_prefix = "rds-ingress-5432-"
  description = "Allow inbound to Postgres from Lambda SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    security_groups          = [var.allowed_sg_id]
    description              = "Allow Postgres from Lambda security group"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, {
    Name = "rds-private-sg"
  })
}

# Optimized parameter group for PostgreSQL
resource "aws_db_parameter_group" "contact_db_params" {
  name   = "contact-db-params"
  family = "postgres14"

  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory*20/100}"  # 20% of instance memory
  }

  parameter {
    name  = "work_mem"
    value = "8388608"  # 8MB
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = var.tags
}

# RDS Database with performance optimizations
resource "aws_db_instance" "contact_db" {
  # Use optimized parameter group
  parameter_group_name = aws_db_parameter_group.contact_db_params.name
  
  # Enable enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  # Enable performance insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  identifier            = var.db_identifier
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  # Reliability improvements
  storage_type            = var.storage_type
  backup_retention_period = 7
  multi_az                = true
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Security but Free Tier friendly
  storage_encrypted   = var.storage_encrypted
  publicly_accessible = var.publicly_accessible
  deletion_protection = var.deletion_protection

  # Database configuration
  username = var.db_username
  password = var.db_password
  db_name  = var.db_name

  vpc_security_group_ids = [aws_security_group.rds_ingress.id]

  # Important: Skip final snapshot to avoid charges
  skip_final_snapshot      = var.skip_final_snapshot
  delete_automated_backups = var.delete_automated_backups

  tags = merge(var.tags, {
    Name = var.db_identifier
  })
}
