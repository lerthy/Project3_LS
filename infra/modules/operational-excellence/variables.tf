# ============================================================================
# OPERATIONAL EXCELLENCE MODULE
# ============================================================================
# This module implements operational excellence practices including:
# - CI/CD monitoring and alerting
# - Manual approval gates
# - Operational dashboards
# - Deployment health checks
# - Infrastructure drift detection

# Variables
# ============================================================================

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "notification_email" {
  description = "Email address for operational notifications"
  type        = string
  default     = ""
}

variable "approval_email" {
  description = "Email address for manual approval notifications"
  type        = string
  default     = ""
}

variable "infra_pipeline_name" {
  description = "Name of the infrastructure CodePipeline"
  type        = string
}

variable "web_pipeline_name" {
  description = "Name of the web CodePipeline"
  type        = string
}

variable "infra_build_project" {
  description = "Name of the infrastructure CodeBuild project"
  type        = string
}

variable "web_build_project" {
  description = "Name of the web CodeBuild project"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "api_gateway_name" {
  description = "Name of the API Gateway to monitor"
  type        = string
}

variable "terraform_state_bucket" {
  description = "S3 bucket containing Terraform state for drift detection"
  type        = string
}

variable "terraform_state_key" {
  description = "S3 key of Terraform state file for drift detection"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Data Sources
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}