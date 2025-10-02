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

data "aws_vpc" "default" {
  default = true
}



# S3 Module
module "s3" {
  source = "./modules/s3"

  providers = {
    aws.standby = aws.standby
  }

  website_bucket_name   = "my-website-bucket-project3-fresh"
  artifacts_bucket_name = "codepipeline-artifacts-project3-fresh"
  cloudfront_oai_id     = module.cloudfront.origin_access_identity_id
  enable_replication    = false  # Disabled for now
  tags                  = local.common_tags
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"

  s3_bucket_regional_domain_name = module.s3.website_bucket_regional_domain_name
  s3_bucket_name                 = module.s3.website_bucket_name
  price_class                    = var.environment == "production" ? "PriceClass_All" : "PriceClass_100"
  log_retention_days             = var.environment == "production" ? 90 : 30
  tags                           = local.common_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  environment         = var.environment
  db_identifier       = "contact-db-project3"
  db_username         = coalesce(var.db_username, data.aws_ssm_parameter.db_username.value)
  db_password         = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)
  db_name             = coalesce(var.db_name, data.aws_ssm_parameter.db_name.value)
  storage_encrypted   = true
  publicly_accessible = false
  allowed_sg_id       = module.lambda.lambda_security_group_id
  dms_subnet_ids      = data.aws_subnets.default_vpc_subnets.ids
  dms_subnet_group_id = "dms-replication-subnet-group"
  tags                = local.common_tags
}

# Secrets Manager secret for DB credentials (username/password/host/name)
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "project3/db-credentials"
  description = "Database credentials for contact form"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = coalesce(var.db_username, data.aws_ssm_parameter.db_username.value)
    password = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)
    host     = module.rds.rds_address
    database = coalesce(var.db_name, data.aws_ssm_parameter.db_name.value)
    port     = module.rds.rds_port
  })
  depends_on = [module.rds]
}

# Rotation Lambda (AWS managed serverless app) for PostgreSQL single-user rotation
data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "rds_rotation" {
  name             = "project3-rds-rotation"
  application_id   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  parameters = {
    functionName          = "project3-rds-rotation"
    vpcSubnetIds          = join(",", data.aws_subnets.default_vpc_subnets.ids)
    vpcSecurityGroupIds   = module.lambda.lambda_security_group_id
  }
  semantic_version = "1.1.188"
  tags             = local.common_tags
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rds_rotation.outputs["RotationLambdaARN"]
  rotation_rules {
    automatically_after_days = 30
  }
  depends_on = [aws_secretsmanager_secret_version.db_credentials_version]
}

# Lambda Module
module "lambda" {
  source = "./modules/lambda"

  function_name     = "contact-form"
  lambda_zip_path   = "lambda.zip"
  lambda_role_name  = "lambda_exec_role_project3"
  aws_region        = var.aws_region
  db_secret_arn     = aws_secretsmanager_secret.db_credentials.arn
  private_subnet_ids = data.aws_subnets.default_vpc_subnets.ids
  tags              = local.common_tags
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"

  api_name            = "contact-api"
  stage_name          = "dev"
  lambda_invoke_arn   = module.lambda.lambda_invoke_arn
  aws_region          = var.aws_region
  log_retention_days  = var.environment == "production" ? 90 : 7
  tags                = local.common_tags
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
  repository_id            = "lerthy/Project3_LS"
  branch_name              = "develop"
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
  lambda_function_name = module.lambda.lambda_function_name
  api_gateway_id       = module.api_gateway.api_gateway_id
  api_gateway_stage    = "dev"
  tags                 = local.common_tags
}