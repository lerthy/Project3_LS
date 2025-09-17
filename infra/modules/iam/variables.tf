variable "codepipeline_role_name" {
  description = "Name of the CodePipeline IAM role"
  type        = string
}

variable "codebuild_role_name" {
  description = "Name of the CodeBuild IAM role"
  type        = string
}

variable "artifacts_bucket_arn" {
  description = "ARN of the CodePipeline artifacts S3 bucket"
  type        = string
}

variable "website_bucket_arn" {
  description = "ARN of the website S3 bucket"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
