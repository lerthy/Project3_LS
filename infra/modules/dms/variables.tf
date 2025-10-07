variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "replication_instance_id" {
  description = "DMS replication instance identifier"
  type        = string
  default     = "rds-replication-instance"
}

variable "replication_instance_class" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.t3.small"
}

variable "allocated_storage" {
  description = "Allocated storage for DMS replication instance in GB"
  type        = number
  default     = 50
}

variable "multi_az" {
  description = "Enable Multi-AZ for DMS replication instance"
  type        = bool
  default     = false
}

variable "subnet_group_id" {
  description = "DMS replication subnet group ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DMS replication"
  type        = list(string)
}

variable "replication_task_id" {
  description = "DMS replication task identifier"
  type        = string
  default     = "rds-to-standby"
}

# Source Database (Primary RDS)
variable "source_db_endpoint" {
  description = "Primary RDS endpoint (without port)"
  type        = string
}

variable "source_db_port" {
  description = "Primary RDS port"
  type        = number
  default     = 5432
}

variable "source_db_username" {
  description = "Primary RDS username"
  type        = string
}

variable "source_db_password" {
  description = "Primary RDS password"
  type        = string
  sensitive   = true
}

# Target Database (Standby RDS)
variable "target_db_endpoint" {
  description = "Standby RDS endpoint (without port)"
  type        = string
}

variable "target_db_port" {
  description = "Standby RDS port"
  type        = number
  default     = 5432
}

variable "target_db_username" {
  description = "Standby RDS username"
  type        = string
}

variable "target_db_password" {
  description = "Standby RDS password"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Database name for both source and target"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all DMS resources"
  type        = map(string)
  default     = {}
}
