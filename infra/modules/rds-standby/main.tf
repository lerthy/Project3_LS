# Standby RDS instance in a different region (e.g., us-west-2)

# Note: Using generated password directly from primary RDS module

provider "aws" {
  alias  = "standby"
  region = var.region
}

data "aws_vpc" "standby" {
  provider = aws.standby
  default  = true
}

resource "aws_security_group" "rds_ingress_standby" {
  provider    = aws.standby
  name_prefix = "rds-ingress-5432-standby-"
  description = "Allow inbound to Postgres from Lambda SG (standby)"
  vpc_id      = data.aws_vpc.standby.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.0/16"] # Only allow from standby VPC CIDR
    description = "Allow Postgres from standby VPC only"
  }

  # No egress rules needed for RDS - databases don't initiate outbound connections

  tags = merge(var.tags, { Name = "rds-standby-private-sg" })
}

resource "aws_db_instance" "contact_db_standby" {
  provider                = aws.standby
  identifier              = var.db_identifier
  engine                  = "postgres"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  storage_type            = "gp2"
  backup_retention_period = 7
  multi_az                = false # Standby is single-AZ for cost, but ensure primary is Multi-AZ
  # NOTE: For cross-region replication, consider AWS DMS or PostgreSQL logical replication.
  # Example (not implemented):
  # resource "aws_dms_replication_task" "rds_to_standby" { ... }
  # AWS RDS automated backups minimum is 1 day. For 15-min backups, consider Aurora or custom automation.
  storage_encrypted        = true
  publicly_accessible      = false
  deletion_protection      = true
  username                 = var.db_username
  password                 = var.generated_password
  db_name                  = var.db_name
  vpc_security_group_ids   = [aws_security_group.rds_ingress_standby.id]
  skip_final_snapshot      = true
  delete_automated_backups = false
  tags                     = merge(var.tags, { Name = var.db_identifier })
}
