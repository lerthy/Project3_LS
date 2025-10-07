# ============================================================================
# LAMBDA SECRETS MANAGEMENT
# ============================================================================
# This file contains additional secrets access configuration for the Lambda function
# Note: Basic secrets policy already exists in main.tf

# Data Source for Secret Metadata
# ============================================================================
# This data source provides metadata about the secret passed to the Lambda function

data "aws_secretsmanager_secret" "db_credentials" {
  arn = var.db_secret_arn
}

# Additional Secrets Configuration (if needed)
# ============================================================================
# The main secrets access policy is already configured in main.tf
# This file can be extended for additional secrets management features