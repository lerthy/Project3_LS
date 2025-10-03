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
  description = "Email address for backup notifications"
  type        = string
  default     = ""
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "standby_region" {
  description = "Standby AWS region"
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

variable "backup_retention_hours" {
  description = "Number of hours to retain hourly backups"
  type        = number
  default     = 168  # 7 days
}

variable "backup_bucket_name" {
  description = "S3 bucket name for backup metadata"
  type        = string
  default     = "rpo-backup-metadata"
}

variable "dms_task_arn" {
  description = "DMS replication task ARN for monitoring lag"
  type        = string
  default     = ""
}
