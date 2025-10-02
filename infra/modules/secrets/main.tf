# ============================================================================
# SECRETS MANAGER WITH CUSTOMER-MANAGED KMS
# ============================================================================
# Enhanced secrets management with customer-managed KMS encryption

# KMS Key for Secrets Manager Encryption
resource "aws_kms_key" "secrets_manager_encryption" {
  description = "KMS key for Secrets Manager encryption"
  
  # Key policy allowing root account and Secrets Manager service access
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager Service"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Access to Secrets"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name = "secrets-manager-encryption-key"
    Type = "secrets-encryption"
  })
}

resource "aws_kms_alias" "secrets_manager_encryption" {
  name          = "alias/secrets-manager-encryption"
  target_key_id = aws_kms_key.secrets_manager_encryption.key_id
}

# Enhanced RDS Secrets with Customer-Managed KMS
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "rds/contact-db/credentials"
  description = "RDS credentials for contact database"
  
  # Use customer-managed KMS key
  kms_key_id = aws_kms_key.secrets_manager_encryption.arn
  
  # Enhanced security settings
  replica {
    region     = var.replica_region
    kms_key_id = aws_kms_key.secrets_manager_encryption.arn
  }
  
  tags = merge(var.tags, {
    Name = "rds-credentials"
    Type = "database-secret"
  })
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = var.db_host
    port     = 5432
    dbname   = var.db_name
  })
}

# Automatic rotation configuration with enhanced security
resource "aws_secretsmanager_secret_rotation" "rds_credentials" {
  count = var.enable_rotation ? 1 : 0
  
  secret_id           = aws_secretsmanager_secret.rds_credentials.id
  rotation_lambda_arn = var.rotation_lambda_arn
  
  rotation_rules {
    automatically_after_days = 30
  }
  
  depends_on = [aws_secretsmanager_secret_version.rds_credentials]
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
