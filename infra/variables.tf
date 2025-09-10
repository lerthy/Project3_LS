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
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}
