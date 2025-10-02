variable "billing_alarm_name" {
  description = "Name of the billing alarm"
  type        = string
  default     = "billing-alarm-5-usd"
}

variable "billing_threshold" {
  description = "Billing threshold in USD"
  type        = string
  default     = "5"
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm is triggered"
  type        = list(string)
  default     = []
}

variable "lambda_function_name" {
  description = "Lambda function name for alarms"
  type        = string
}

variable "api_gateway_id" {
  description = "API Gateway ID for alarms"
  type        = string
}

variable "api_gateway_stage" {
  description = "API Gateway stage name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "primary_rds_id" {
  description = "Primary RDS instance identifier"
  type        = string
}

variable "standby_rds_id" {
  description = "Standby RDS instance identifier"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "standby_region" {
  description = "Standby AWS region"
  type        = string
}

variable "primary_lambda_name" {
  description = "Primary Lambda function name"
  type        = string
}

variable "standby_lambda_name" {
  description = "Standby Lambda function name"
  type        = string
}

variable "primary_api_name" {
  description = "Primary API Gateway name"
  type        = string
}

variable "standby_api_name" {
  description = "Standby API Gateway name"
  type        = string
}

variable "primary_health_check_id" {
  description = "Primary Route53 health check ID"
  type        = string
}

variable "standby_health_check_id" {
  description = "Standby Route53 health check ID"
  type        = string
}
