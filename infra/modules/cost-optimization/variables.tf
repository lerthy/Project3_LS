variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "stop_schedule" {
  description = "Cron expression for stopping resources (default: 7 PM UTC weekdays)"
  type        = string
  default     = "cron(0 19 ? * MON-FRI *)"
}

variable "start_schedule" {
  description = "Cron expression for starting resources (default: 8 AM UTC weekdays)"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "rds_identifier" {
  description = "RDS instance identifier to schedule"
  type        = string
  default     = "contact-db"
}

variable "lambda_function_name" {
  description = "Lambda function name for provisioned concurrency scheduling"
  type        = string
  default     = "contact-form"
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for scheduler notifications"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
