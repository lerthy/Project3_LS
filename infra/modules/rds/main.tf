resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_id = "dms-replication-subnet-group"
  subnet_ids                  = var.dms_subnet_ids
  tags                       = var.tags
  replication_subnet_group_description = "Subnet group for DMS replication instance"
}
resource "aws_dms_replication_instance" "rds_replication" {
  count = var.environment == "production" ? 1 : 0  # Only create DMS for production
  
  replication_instance_id     = "rds-replication-instance"
  allocated_storage           = var.environment == "production" ? 100 : 50  # Smaller storage for non-prod
  replication_instance_class  = var.environment == "production" ? "dms.t3.medium" : "dms.t3.small"
  engine_version              = "3.4.6"
  publicly_accessible         = false
  multi_az                    = var.environment == "production" ? true : false  # Cost optimization
  vpc_security_group_ids      = [aws_security_group.rds_ingress.id]
  replication_subnet_group_id = var.dms_subnet_group_id
  tags = var.tags
}

resource "aws_dms_endpoint" "source" {
  count = var.environment == "production" ? 1 : 0  # Only create for production
  
  endpoint_id   = "source-endpoint"
  endpoint_type = "source"
  engine_name   = "postgres"
  username      = var.db_username
  password      = var.db_password
  server_name   = aws_db_instance.contact_db.address
  port          = 5432
  database_name = var.db_name
  ssl_mode      = "require"
}

resource "aws_dms_endpoint" "target" {
  count = var.environment == "production" ? 1 : 0  # Only create for production
  
  endpoint_id   = "target-endpoint"
  endpoint_type = "target"
  engine_name   = "postgres"
  username      = var.db_username
  password      = var.db_password
  server_name   = var.standby_rds_address # Set this variable to your standby RDS address
  port          = 5432
  database_name = var.db_name
  ssl_mode      = "require"
}

resource "aws_dms_replication_task" "rds_to_standby" {
  count = var.environment == "production" ? 1 : 0  # Only create for production
  
  replication_task_id        = "rds-to-standby"
  migration_type             = "cdc"
  replication_instance_arn   = aws_dms_replication_instance.rds_replication[0].arn
  source_endpoint_arn        = aws_dms_endpoint.source[0].arn
  target_endpoint_arn        = aws_dms_endpoint.target[0].arn
  table_mappings             = file("${path.module}/dms-table-mappings.json")
  replication_task_settings  = file("${path.module}/dms-task-settings.json")
  tags = var.tags
}
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

  # Reliability improvements - conditional Multi-AZ based on environment
  storage_type            = var.storage_type
  backup_retention_period = var.environment == "production" ? 7 : 1
  multi_az                = var.environment == "production" ? true : false
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  # Cross-region replication example using AWS DMS
  # You must create source/target endpoints and a replication instance.
  # Uncomment and configure the following resources as needed:

  # resource "aws_dms_replication_instance" "rds_replication" {
  #   allocated_storage    = 100
  #   replication_instance_class = "dms.t3.medium"
  #   engine_version      = "3.4.6"
  #   publicly_accessible = false
  #   multi_az            = true
  #   tags = var.tags
  # }

  # resource "aws_dms_endpoint" "source" {
  #   endpoint_id = "source-endpoint"
  #   endpoint_type = "source"
  #   engine_name = "postgres"
  #   username = var.db_username
  #   password = var.db_password
  #   server_name = aws_db_instance.contact_db.address
  #   port = 5432
  #   database_name = var.db_name
  # }

  # resource "aws_dms_endpoint" "target" {
  #   endpoint_id = "target-endpoint"
  #   endpoint_type = "target"
  #   engine_name = "postgres"
  #   username = var.db_username
  #   password = var.db_password
  #   server_name = module.rds_standby.rds_address
  #   port = 5432
  #   database_name = var.db_name
  # }

  # resource "aws_dms_replication_task" "rds_to_standby" {
  #   replication_task_id          = "rds-to-standby"
  #   migration_type               = "cdc"
  #   replication_instance_arn    = aws_dms_replication_instance.rds_replication.arn
  #   source_endpoint_arn         = aws_dms_endpoint.source.arn
  #   target_endpoint_arn         = aws_dms_endpoint.target.arn
  #   table_mappings              = file("${path.module}/dms-table-mappings.json")
  #   replication_task_settings   = file("${path.module}/dms-task-settings.json")
  #   tags = var.tags
  # }

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
