# ============================================================================
# SECRETS MANAGEMENT
# ============================================================================
# This file contains all secrets management resources for the infrastructure
# including database credentials, API keys, and other sensitive data.

# Primary Region Database Credentials
# ============================================================================

# Create secret for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "project3/db-credentials"
  description = "Database credentials for contact form primary region"

  tags = merge(local.common_tags, {
    Name   = "project3-db-credentials"
    Type   = "database-credentials"
    Region = "primary"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = module.rds.rds_address
    database = var.db_name
    port     = module.rds.rds_port
  })

  depends_on = [module.rds]
}

# Standby Region Database Credentials
# ============================================================================

resource "aws_secretsmanager_secret" "db_credentials_standby" {
  provider = aws.standby

  name        = "project3/db-credentials-standby"
  description = "Database credentials for contact form standby region"

  tags = merge(local.common_tags, {
    Name   = "project3-db-credentials-standby"
    Type   = "database-credentials"
    Region = "standby"
  })

  lifecycle {
    ignore_changes = [name, description, tags]
  }
}

# Import the existing secret
import {
  to = aws_secretsmanager_secret.db_credentials_standby
  id = "project3/db-credentials-standby"
}

resource "aws_secretsmanager_secret_version" "db_credentials_standby_version" {
  provider = aws.standby

  secret_id = aws_secretsmanager_secret.db_credentials_standby.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = module.rds_standby.standby_db_endpoint
    database = var.db_name
    port     = module.rds_standby.standby_db_port
  })

  depends_on = [module.rds_standby]
}

# Secret Rotation Configuration
# ============================================================================

# Rotation Lambda (AWS managed serverless app) for PostgreSQL single-user rotation
data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Temporarily commented out due to Python runtime compatibility issues
# Will be re-enabled after main infrastructure is deployed
/*
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rds_rotation" {
  name           = "SecretsManagerRDSPostgreSQLRotationSingleUser"
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"

  parameters = {
    endpoint            = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    functionName        = "SecretsManagerRDSPostgreSQLRotationSingleUser"
    vpcSecurityGroupIds = module.rds.rds_security_group_id
    vpcSubnetIds        = join(",", data.aws_subnets.default_vpc_subnets.ids)
  }

  capabilities     = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]
  semantic_version = "1.1.348"
  tags             = local.common_tags
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = data.aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rds_rotation.outputs["RotationLambdaARN"]

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_secretsmanager_secret_version.db_credentials_version]
}
*/

# GitHub Webhook Secret (for CI/CD)
# ============================================================================

resource "aws_secretsmanager_secret" "github_webhook" {
  name        = "project3/github-webhook"
  description = "GitHub webhook secret for CI/CD pipeline"

  tags = merge(local.common_tags, {
    Name = "project3-github-webhook"
    Type = "webhook-secret"
  })
}

resource "aws_secretsmanager_secret_version" "github_webhook_version" {
  secret_id = aws_secretsmanager_secret.github_webhook.id
  secret_string = jsonencode({
    webhook_secret = var.github_webhook_secret
  })
}