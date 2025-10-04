# ============================================================================
# RDS SECRETS MANAGEMENT
# ============================================================================
# This file contains KMS keys, password generation, and security configuration for RDS

# KMS Key for RDS Encryption
# ============================================================================

resource "aws_kms_key" "rds_encryption" {
  description = "KMS key for RDS encryption - ${var.db_identifier}"
  
  # Key policy allowing root account and RDS service access
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
        Sid    = "Allow RDS Service"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
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
        Sid    = "Allow CodeBuild Service"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/codebuild-role-project3-v2"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name = "rds-encryption-key-${var.db_identifier}"
    Type = "rds-encryption"
  })
}

resource "aws_kms_alias" "rds_encryption" {
  name          = "alias/rds-encryption-${var.db_identifier}"
  target_key_id = aws_kms_key.rds_encryption.key_id
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Random Password Generation (if needed)
# ============================================================================

resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 32
  special = true
  
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Security Configuration
# ============================================================================

# Additional security group rules for database access
resource "aws_security_group_rule" "rds_secrets_manager_access" {
  count = var.enable_secrets_manager_access ? 1 : 0
  
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]  # Adjust based on your VPC CIDR
  security_group_id = aws_security_group.rds_ingress.id
  description       = "Allow Secrets Manager Lambda access"
}