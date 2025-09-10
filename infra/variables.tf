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
  default     = "eu-north-1"
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

variable "github_token" {
  description = "GitHub personal access token for CodePipeline source integration"
  type        = string
  sensitive   = true
  default     = ""
}
