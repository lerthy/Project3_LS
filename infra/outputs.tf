output "bucket_name" {
  description = "S3 bucket name hosting the website"
  value       = module.s3.website_bucket_name
}

output "cloudfront_url" {
  description = "CloudFront distribution domain name for the website"
  value       = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for cache invalidations"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "api_gateway_url" {
  description = "Invoke URL for the contact form API"
  value       = module.api_gateway.api_gateway_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint for database connections"
  value       = module.rds.rds_endpoint
}

output "infra_pipeline_name" {
  description = "Name of the infrastructure CodePipeline"
  value       = module.codepipeline.infra_pipeline_name
}

output "web_pipeline_name" {
  description = "Name of the web application CodePipeline"
  value       = module.codepipeline.web_pipeline_name
}

output "codepipeline_artifacts_bucket" {
  description = "S3 bucket used for CodePipeline artifacts"
  value       = module.s3.artifacts_bucket_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.lambda_function_arn
}

output "billing_alarm_name" {
  description = "Name of the billing alarm"
  value       = module.monitoring.billing_alarm_name
}

output "infra_webhook_url" {
  description = "Webhook URL for infrastructure pipeline"
  value       = module.codepipeline.infra_webhook_url
}

output "web_webhook_url" {
  description = "Webhook URL for web pipeline"
  value       = module.codepipeline.web_webhook_url
}

# ============================================================================
# SECRETS OUTPUTS
# ============================================================================

output "db_secret_arn" {
  description = "ARN of the database credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
  sensitive   = true
}

output "db_secret_name" {
  description = "Name of the database credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_secret_standby_arn" {
  description = "ARN of the standby database credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials_standby.arn
  sensitive   = true
}

output "github_webhook_secret_arn" {
  description = "ARN of the GitHub webhook secret in Secrets Manager"
  value       = aws_secretsmanager_secret.github_webhook.arn
  sensitive   = true
}

# RDS KMS Key outputs (from RDS module)
output "rds_kms_key_arn" {
  description = "ARN of the KMS key used for RDS encryption"
  value       = module.rds.kms_key_arn
}

output "rds_kms_key_alias" {
  description = "Alias of the KMS key used for RDS encryption"
  value       = module.rds.kms_key_alias
}