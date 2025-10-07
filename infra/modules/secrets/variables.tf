variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "replica_region" {
  description = "Region for secret replication"
  type        = string
  default     = "us-west-2"
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "enable_rotation" {
  description = "Enable automatic password rotation"
  type        = bool
  default     = true
}

variable "rotation_lambda_arn" {
  description = "ARN of the Lambda function for password rotation"
  type        = string
  default     = ""
}
