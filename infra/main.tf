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
  enable_replication    = var.environment == "production" ? true : false  # Enable for production
  replication_role_arn  = var.environment == "production" ? var.replication_role_arn : ""
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
  db_username         = var.db_username
  db_password         = var.db_password
  db_name             = var.db_name
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
    username = var.db_username
    password = var.db_password
    host     = module.rds.rds_address
    database = var.db_name
    port     = module.rds.rds_port
  })
  depends_on = [module.rds]
}

# Standby Secrets Manager secret for DB credentials
resource "aws_secretsmanager_secret" "db_credentials_standby" {
  provider = aws.standby
  
  name        = "project3/db-credentials-standby"
  description = "Database credentials for contact form standby"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials_standby_version" {
  provider = aws.standby
  
  secret_id     = aws_secretsmanager_secret.db_credentials_standby.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = module.rds_standby.standby_db_endpoint
    database = var.db_name
    port     = module.rds_standby.standby_db_port
  })
  depends_on = [module.rds_standby]
}

# RDS Standby Module (us-west-2)
module "rds_standby" {
  source = "./modules/rds-standby"
  
  providers = {
    aws = aws.standby
  }

  region             = var.standby_region
  db_identifier      = "contact-db-standby"
  db_username        = var.db_username
  db_password        = var.db_password
  db_name           = var.db_name
  instance_class     = var.environment == "production" ? "db.t3.small" : "db.t3.micro"
  allocated_storage  = 20
  max_allocated_storage = 100
  tags              = local.common_tags
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

# Lambda Standby Module (us-west-2)
module "lambda_standby" {
  source = "./modules/lambda-standby"
  
  providers = {
    aws = aws.standby
  }

  function_name      = "contact-form-standby"
  lambda_role_arn    = module.lambda.lambda_role_arn
  vpc_id            = module.standby_vpc.vpc_id
  private_subnet_ids = module.standby_vpc.private_subnet_ids
  db_secret_arn     = aws_secretsmanager_secret.db_credentials_standby.arn
  environment       = var.environment
  region            = var.standby_region
  lambda_zip_path   = "lambda.zip"
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

# API Gateway Standby Module (us-west-2)
module "api_gateway_standby" {
  source = "./modules/api-gateway-standby"
  
  providers = {
    aws = aws.standby
  }

  region            = var.standby_region
  environment       = var.environment
  lambda_invoke_arn = module.lambda_standby.lambda_invoke_arn
  tags              = local.common_tags
}

# Route53 Module for DNS Failover (conditional on hosted zone)
module "route53" {
  source = "./modules/route53"
  count  = var.route53_zone_id != "" ? 1 : 0

  primary_api_dns   = module.api_gateway.api_gateway_url
  standby_api_dns   = module.api_gateway_standby.api_endpoint
  primary_api_ip    = "1.2.3.4"  # Placeholder - would be resolved from API Gateway
  standby_api_ip    = "5.6.7.8"  # Placeholder - would be resolved from API Gateway
  route53_zone_id   = var.route53_zone_id
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
  
  # Multi-region monitoring variables
  primary_rds_id     = module.rds.rds_identifier
  standby_rds_id     = module.rds_standby.standby_db_identifier
  primary_region     = var.aws_region
  standby_region     = var.standby_region
  primary_lambda_name = module.lambda.lambda_function_name
  standby_lambda_name = module.lambda_standby.lambda_function_name
  primary_api_name    = "contact-api"
  standby_api_name    = "${var.environment}-contact-api"
  primary_health_check_id  = length(module.route53) > 0 ? module.route53[0].primary_health_check_id : ""
  standby_health_check_id  = length(module.route53) > 0 ? module.route53[0].standby_health_check_id : ""
  
  tags                 = local.common_tags
}