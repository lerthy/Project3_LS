variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "contact-form"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = "lambda.zip"
}

variable "lambda_role_name" {
  description = "Name of the IAM role for Lambda"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 10
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_pass" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# api_gateway_id variable removed - permission handled in main configuration

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
