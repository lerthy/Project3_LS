variable "region" {
  description = "AWS region for standby RDS"
  type        = string
  default     = "us-west-2"
}

variable "db_identifier" {
  description = "Identifier for standby RDS instance"
  type        = string
  default     = "contact-db-standby"
}

variable "engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "14.17"
}

variable "instance_class" {
  description = "RDS instance class for standby"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage (GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max allocated storage (GB)"
  type        = number
  default     = 100
}

variable "db_username" {
  description = "Standby DB username"
  type        = string
  default     = "standbyuser"
}

variable "db_password" {
  description = "Standby DB password (use secrets manager in prod)"
  type        = string
  default     = "standbypassword"
}

variable "db_name" {
  description = "Standby DB name"
  type        = string
  default     = "contactdbstandby"
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
