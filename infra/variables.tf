variable "db_name" {
  type    = string
  default = "contacts"
}

variable "db_username" {
  type = string
  # Choose a non-reserved username; 'admin', 'postgres', etc. are not allowed
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
  # When empty, password will be read from SSM parameter defined by var.db_password_ssm_name
  default   = ""
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

# SSM parameter names for DB credentials (used when corresponding var is empty)
variable "db_username_ssm_name" {
  type    = string
  default = "/project3/db/username"
}

variable "db_password_ssm_name" {
  type    = string
  default = "/project3/db/password"
}

variable "db_name_ssm_name" {
  type    = string
  default = "/project3/db/name"
}
