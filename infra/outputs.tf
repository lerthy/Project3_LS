output "bucket_name" {
  description = "S3 bucket name hosting the website"
  value       = aws_s3_bucket.website.bucket
}

output "s3_bucket_name" {
  description = "S3 bucket name (alias for compatibility)"
  value       = aws_s3_bucket.website.bucket
}

output "cloudfront_url" {
  description = "CloudFront distribution domain name for the website"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for cache invalidations"
  value       = aws_cloudfront_distribution.cdn.id
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.contact_api.id
}

output "api_gateway_url" {
  description = "Invoke URL for the contact form API"
  value       = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.aws_region}.amazonaws.com/dev/contact"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.contact.function_name
}

output "rds_endpoint" {
  description = "RDS instance endpoint for database connections"
  value       = aws_db_instance.contact_db.endpoint
}

# NOTE: Commented out because infra pipeline is not managed by Terraform (circular dependency)
# output "infra_pipeline_name" {
#   description = "Name of the infrastructure CodePipeline"
#   value       = aws_codepipeline.infra_pipeline.name
# }

output "codepipeline_artifacts_bucket" {
  description = "S3 bucket used for CodePipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline_role.arn
}

output "codebuild_additional_policy_arn" {
  description = "ARN of the additional IAM policy that should be attached to CodeBuild service role"
  value       = aws_iam_policy.codebuild_additional_permissions.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild_role.arn
}

output "infrapipe_project_name" {
  description = "Name of the infrastructure CodeBuild project"
  value       = aws_codebuild_project.infrapipe.name
}

output "webpipe_project_name" {
  description = "Name of the web CodeBuild project"
  value       = aws_codebuild_project.webpipe.name
}
