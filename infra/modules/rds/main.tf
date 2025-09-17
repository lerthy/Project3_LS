# Default VPC to host RDS security group
data "aws_vpc" "default" {
  default = true
}

# Public inbound for PostgreSQL (demo only)
resource "aws_security_group" "rds_public" {
  name_prefix = "rds-public-ingress-5432-"
  description = "Allow public inbound to Postgres (demo)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    # Demo-only: allow public access so Lambda (not in VPC) can reach RDS
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, {
    Name = "rds-public-sg"
  })
}

# RDS Database
resource "aws_db_instance" "contact_db" {
  identifier            = var.db_identifier
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  # Free Tier optimizations
  storage_type            = var.storage_type
  backup_retention_period = var.backup_retention_period
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

  vpc_security_group_ids = [aws_security_group.rds_public.id]

  # Important: Skip final snapshot to avoid charges
  skip_final_snapshot      = var.skip_final_snapshot
  delete_automated_backups = var.delete_automated_backups

  tags = merge(var.tags, {
    Name = var.db_identifier
  })
}
