# ============================================================================
# LAMBDA SECRETS MANAGEMENT
# ============================================================================
# This file contains additional secrets access configuration for the Lambda function
# Note: Basic secrets policy already exists in main.tf

# Data Source for Secret Metadata (Optional)
# ============================================================================

data "aws_secretsmanager_secret" "db_credentials" {
  count = var.db_secret_arn != "" ? 1 : 0
  arn   = var.db_secret_arn
}

# KMS Key Access for Secrets (if using customer-managed keys)
# ============================================================================

resource "aws_iam_role_policy" "lambda_kms_policy" {
  count = var.kms_key_arn != "" ? 1 : 0
  name  = "lambda-kms-access-policy"
  role  = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}