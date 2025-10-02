variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "replication_role_arn" {
  description = "ARN of the IAM role for S3 replication"
  type        = string
  default     = ""
}
variable "standby_region" {
  description = "AWS region for standby resources"
  type        = string
  default     = "us-west-2"
}
variable "db_name" {
  description = "Postgres database name to create/use"
  type        = string
  default     = "contacts"
}

variable "db_username" {
  description = "Database username. Avoid reserved names like 'postgres' or 'admin'"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Database password. If empty, read from SSM at db_password_ssm_name"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

# SSM parameter names for DB credentials (used when corresponding var is empty)
variable "db_username_ssm_name" {
  description = "SSM parameter name that stores the database username"
  type        = string
  default     = "/project3/db/username"
}

variable "db_password_ssm_name" {
  description = "SSM parameter name that stores the database password (SecureString)"
  type        = string
  default     = "/project3/db/password"
}

variable "db_name_ssm_name" {
  description = "SSM parameter name that stores the Postgres database name"
  type        = string
  default     = "/project3/db/name"
}


variable "codestar_connection_arn" {
  description = "ARN of the CodeStar (CodeConnections) connection to GitHub"
  type        = string
  default     = ""
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret for pipeline triggers"
  type        = string
  sensitive   = true
  default     = "your-webhook-secret-here"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS failover (optional)"
  type        = string
  default     = ""
}
