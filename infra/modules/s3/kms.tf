# ============================================================================
# S3 KMS ENCRYPTION KEYS
# ============================================================================
# Customer-managed KMS keys for enhanced S3 security

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
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name = "s3-website-encryption-key"
    Type = "s3-encryption"
  })
}

resource "aws_kms_alias" "s3_website_encryption" {
  name          = "alias/s3-website-encryption"
  target_key_id = aws_kms_key.s3_website_encryption.key_id
}

# KMS Key for S3 CodePipeline Artifacts Encryption
resource "aws_kms_key" "s3_artifacts_encryption" {
  description = "KMS key for S3 CodePipeline artifacts encryption"
  
  # Key policy allowing root account, S3, and CodePipeline services
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
        Sid    = "Allow CodePipeline Service"
        Effect = "Allow"
        Principal = {
          Service = [
            "codepipeline.amazonaws.com",
            "codebuild.amazonaws.com"
          ]
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
    Name = "s3-artifacts-encryption-key"
    Type = "s3-encryption"
  })
}

resource "aws_kms_alias" "s3_artifacts_encryption" {
  name          = "alias/s3-artifacts-encryption"
  target_key_id = aws_kms_key.s3_artifacts_encryption.key_id
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
