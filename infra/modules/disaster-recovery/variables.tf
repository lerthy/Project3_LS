variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "notification_email" {
  description = "Email address for disaster recovery notifications"
  type        = string
  default     = ""
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "standby_region" {
  description = "Standby AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}

variable "primary_rds_identifier" {
  description = "Primary RDS instance identifier"
  type        = string
}

variable "standby_rds_identifier" {
  description = "Standby RDS instance identifier"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "route53_record_name" {
  description = "Route53 record name for failover"
  type        = string
  default     = "api"
}

variable "primary_health_check_id" {
  description = "Route53 health check ID for primary region"
  type        = string
  default     = ""
}

variable "primary_lambda_name" {
  description = "Primary Lambda function name"
  type        = string
}

variable "standby_lambda_name" {
  description = "Standby Lambda function name"
  type        = string
}
