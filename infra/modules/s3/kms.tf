# ============================================================================
# S3 KMS ENCRYPTION KEYS
# ============================================================================
# Customer-managed KMS keys for enhanced S3 security

# Data source to get current caller identity for account ID
data "aws_caller_identity" "current" {}

# KMS Key for S3 Website Bucket Encryption
resource "aws_kms_key" "s3_website_encryption" {
  description = "KMS key for S3 website bucket encryption"

  # Key policy allowing root account and S3 service access
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
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
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
        Sid    = "Allow CloudFront Service"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
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

  # Enable key rotation for security
  enable_key_rotation = true

  # Tags for resource management
  tags = {
    Name        = "project3-s3-website-kms-key"
    Environment = "dev"
    Project     = "project3"
    CreatedBy   = "terraform"
  }
}

# Alias for the KMS key for better readability
resource "aws_kms_alias" "s3_website_encryption" {
  name          = "alias/project3-s3-website-dev"
  target_key_id = aws_kms_key.s3_website_encryption.key_id
}

# KMS Key for S3 CodePipeline Bucket Encryption
resource "aws_kms_key" "s3_codepipeline_encryption" {
  description = "KMS key for S3 CodePipeline bucket encryption"

  # Key policy allowing root account and CodePipeline/S3 service access
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
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
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
        Sid    = "Allow CloudFront Service"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
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
        Sid    = "Allow CodePipeline Service"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
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
          Service = "codebuild.amazonaws.com"
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

  # Enable key rotation for security
  enable_key_rotation = true

  # Tags for resource management
  tags = {
    Name        = "project3-s3-codepipeline-kms-key"
    Environment = "dev"
    Project     = "project3"
    CreatedBy   = "terraform"
  }
}

# Alias for the CodePipeline KMS key
resource "aws_kms_alias" "s3_codepipeline_encryption" {
  name          = "alias/project3-s3-codepipeline-dev"
  target_key_id = aws_kms_key.s3_codepipeline_encryption.key_id
}
