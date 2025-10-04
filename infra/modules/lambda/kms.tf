# ============================================================================
# LAMBDA KMS ENCRYPTION
# ============================================================================
# Customer-managed KMS key for Lambda environment variables encryption

# KMS Key for Lambda Environment Variables Encryption
resource "aws_kms_key" "lambda_env_encryption" {
  description = "KMS key for Lambda environment variables encryption"
  
  # Key policy allowing root account and Lambda service access
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
        Sid    = "Allow account principals with IAM permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:*"
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
        Sid    = "Allow Lambda Service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
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
    Name = "lambda-env-encryption-key"
    Type = "lambda-encryption"
  })
}

resource "aws_kms_alias" "lambda_env_encryption" {
  name          = "alias/lambda-env-encryption"
  target_key_id = aws_kms_key.lambda_env_encryption.key_id
}

# Note: aws_caller_identity data source defined in main.tf
