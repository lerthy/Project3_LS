# ============================================================================
# TERRAFORM IMPORT BLOCKS
# ============================================================================
# Import existing AWS resources to prevent creation conflicts during deployment
# This file contains all import statements to keep main.tf clean and organized

# Import existing Secrets Manager secrets
import {
  to = aws_secretsmanager_secret.db_credentials
  id = "project3/db-credentials"
}

import {
  to = aws_secretsmanager_secret.db_credentials_standby
  id = "project3/db-credentials-standby"
}

# Import existing CloudWatch Log Groups
import {
  to = module.lambda_standby.aws_cloudwatch_log_group.lambda
  id = "/aws/lambda/contact-form-standby"
}

# Import existing IAM Roles
import {
  to = module.lambda.aws_iam_role.lambda_exec
  id = "lambda_exec_role_project3"
}

import {
  to = module.iam.aws_iam_role.codepipeline_role
  id = "codepipeline-role-project3"
}

import {
  to = module.iam.aws_iam_role.codebuild_role
  id = "codebuild-role-project3-v2"
}

# Import existing KMS Resources
import {
  to = module.lambda.aws_kms_alias.lambda_env_encryption
  id = "alias/lambda-env-encryption"
}

# Import existing Lambda Resources
import {
  to = module.lambda.aws_lambda_function.contact
  id = "contact-form"
}

import {
  to = module.lambda.aws_lambda_alias.contact_live
  id = "contact-form/live"
}