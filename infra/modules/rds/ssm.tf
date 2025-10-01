resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/rds/rds_endpoint"
  type  = "String"
  value = aws_db_instance.contact_db.endpoint

  tags = var.tags
}

resource "aws_ssm_parameter" "rds_address" {
  name  = "/rds/rds_address"
  type  = "String"
  value = aws_db_instance.contact_db.address

  tags = var.tags
}

resource "aws_ssm_parameter" "rds_port" {
  name  = "/rds/rds_port"
  type  = "String"
  value = tostring(aws_db_instance.contact_db.port)

  tags = var.tags
}

resource "aws_ssm_parameter" "rds_arn" {
  name  = "/rds/rds_arn"
  type  = "String"
  value = aws_db_instance.contact_db.arn

  tags = var.tags
}

resource "aws_ssm_parameter" "security_group_id" {
  name  = "/rds/security_group_id"
  type  = "String"
  value = aws_security_group.rds_ingress.id

  tags = var.tags
}

# Store sensitive database password as SecureString
resource "aws_ssm_parameter" "db_password" {
  name  = "/rds/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = var.tags
}

# Store database credentials for reference
resource "aws_ssm_parameter" "db_username" {
  name  = "/rds/db_username"
  type  = "String"
  value = var.db_username

  tags = var.tags
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/rds/db_name"
  type  = "String"
  value = var.db_name

  tags = var.tags
}
