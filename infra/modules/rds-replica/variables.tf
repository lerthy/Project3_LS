variable "region" {
  description = "The AWS region where the RDS replica will be created"
  type        = string
}

variable "db_identifier" {
  description = "Identifier for the RDS replica instance"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS replica will be created"
  type        = string
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs that are allowed to access the RDS replica"
  type        = list(string)
}

variable "source_db_arn" {
  description = "ARN of the source RDS instance to create replica from"
  type        = string
}

variable "instance_class" {
  description = "The instance class for the RDS replica"
  type        = string
  default     = "db.t3.medium"
}

variable "monitoring_role_arn" {
  description = "ARN of the IAM role used for enhanced monitoring"
  type        = string
}

variable "alarm_actions" {
  description = "List of ARNs to notify when replica lag alarm triggers"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected"
  type        = number
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60 seconds."
  }
}