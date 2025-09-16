# SSM parameters for DB credentials (read-only)
data "aws_ssm_parameter" "db_username" {
  name = var.db_username_ssm_name
}

data "aws_ssm_parameter" "db_password" {
  name            = var.db_password_ssm_name
  with_decryption = true
}

data "aws_ssm_parameter" "db_name" {
  name = var.db_name_ssm_name
}

data "aws_caller_identity" "current" {}

# Common tags
locals {
  common_tags = {
    Environment = "development"
    Project     = "assignment"
    ManagedBy   = "terraform"
  }
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  website_bucket_name   = "my-website-bucket-project3"
  artifacts_bucket_name = "codepipeline-artifacts-project3"
  cloudfront_oai_id     = module.cloudfront.origin_access_identity_id
  tags                  = local.common_tags
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"

  s3_bucket_regional_domain_name = module.s3.website_bucket_regional_domain_name
  tags                           = local.common_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  db_identifier = "contact-db-project3"
  db_username   = coalesce(var.db_username, data.aws_ssm_parameter.db_username.value)
  db_password   = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)
  db_name       = coalesce(var.db_name, data.aws_ssm_parameter.db_name.value)
  tags          = local.common_tags
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"

  function_name     = "contact-form"
  lambda_zip_path   = "lambda.zip"
  lambda_role_name  = "lambda_exec_role_project3"
  aws_region        = var.aws_region
  tags              = local.common_tags

  depends_on = [module.rds]
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"

  api_name          = "contact-api"
  stage_name        = "dev"
  lambda_invoke_arn = module.lambda.lambda_invoke_arn
  aws_region        = var.aws_region
  tags              = local.common_tags
}

# Lambda permission for API Gateway (created after both modules)
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke-project3"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.api_gateway_id}/*/*/contact"
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  codepipeline_role_name        = "codepipeline-role-project3"
  codebuild_role_name          = "codebuild-role-project3"
  artifacts_bucket_arn         = module.s3.artifacts_bucket_arn
  website_bucket_arn           = module.s3.website_bucket_arn
  codestar_connection_arn      = var.codestar_connection_arn
  aws_region                   = var.aws_region
  lambda_function_arn          = module.lambda.lambda_function_arn
  cloudfront_distribution_id   = module.cloudfront.cloudfront_distribution_id
  tags                         = local.common_tags

  depends_on = [module.s3, module.lambda, module.cloudfront]
}

# CodePipeline Module (now in cicd folder at root)
module "codepipeline" {
  source = "../cicd"

  infra_build_project_name = "project3-infra-build"
  web_build_project_name   = "project3-web-build"
  infra_pipeline_name      = "project3-infra-pipeline"
  web_pipeline_name        = "project3-web-pipeline"
  codebuild_role_arn       = module.iam.codebuild_role_arn
  codepipeline_role_arn    = module.iam.codepipeline_role_arn
  artifacts_bucket_name    = module.s3.artifacts_bucket_name
  codestar_connection_arn  = var.codestar_connection_arn
  repository_id            = var.repository_id
  branch_name              = var.branch_name
  aws_region               = var.aws_region
  infra_path_filters       = ["infra/**/*"]
  web_path_filters         = ["web/**/*"]
  github_webhook_secret    = var.github_webhook_secret
  tags                     = local.common_tags

  depends_on = [module.iam, module.s3]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  billing_alarm_name = "billing-alarm-5-usd"
  billing_threshold  = "5"
  alarm_actions      = []
  tags               = local.common_tags
}