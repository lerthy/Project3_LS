variable "infra_build_project_name" {
  description = "Name of the infrastructure CodeBuild project"
  type        = string
}

variable "web_build_project_name" {
  description = "Name of the web application CodeBuild project"
  type        = string
}

variable "infra_pipeline_name" {
  description = "Name of the infrastructure CodePipeline"
  type        = string
}

variable "web_pipeline_name" {
  description = "Name of the web application CodePipeline"
  type        = string
}

variable "infra_buildspec_path" {
  description = "Path to the infrastructure buildspec file"
  type        = string
  default     = "buildspec-infra.yml"
}

variable "web_buildspec_path" {
  description = "Path to the web application buildspec file"
  type        = string
  default     = "buildspec-web.yml"
}

variable "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  type        = string
}

variable "codepipeline_role_arn" {
  description = "ARN of the CodePipeline IAM role"
  type        = string
}

variable "artifacts_bucket_name" {
  description = "Name of the CodePipeline artifacts S3 bucket"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection"
  type        = string
}

variable "repository_id" {
  description = "GitHub repository ID"
  type        = string
}

variable "branch_name" {
  description = "GitHub branch name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "infra_path_filters" {
  description = "Path filters for infrastructure pipeline"
  type        = list(string)
  default     = ["infra/**/*"]
}

variable "web_path_filters" {
  description = "Path filters for web pipeline"
  type        = list(string)
  default     = ["web/**/*"]
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret for pipeline triggers"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "approval_email" {
  description = "Email address for manual approval notifications"
  type        = string
  default     = ""
}
