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
  default     = "PriceClass_100"  # US, Canada, Europe only
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
