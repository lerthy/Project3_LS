# Standby RDS instance in a different region (e.g., us-west-2)
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
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"] # Adjust to match your security requirements
    description     = "Allow Postgres from Lambda security group"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

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
  multi_az                = false
  storage_encrypted       = true
  publicly_accessible     = false
  deletion_protection     = true
  username                = var.db_username
  password                = var.db_password
  db_name                 = var.db_name
  vpc_security_group_ids  = [aws_security_group.rds_ingress_standby.id]
  skip_final_snapshot     = true
  delete_automated_backups = false
  tags = merge(var.tags, { Name = var.db_identifier })
}
