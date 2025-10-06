variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for generating log bucket name"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class for cost optimization"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe only
}

variable "log_retention_days" {
  description = "Number of days to retain CloudFront logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "s3_standby_bucket_regional_domain_name" {
  description = "Regional domain name of the standby S3 bucket for failover"
  type        = string
  default     = ""
}

variable "enable_origin_failover" {
  description = "Enable CloudFront origin failover to standby S3 bucket"
  type        = bool
  default     = false
}
