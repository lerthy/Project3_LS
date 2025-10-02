variable "replication_role_arn" {
  description = "ARN of the IAM role for S3 replication"
  type        = string
  default     = ""
}

variable "enable_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}
variable "website_bucket_name" {
  description = "Name of the S3 bucket for website hosting"
  type        = string
}

variable "artifacts_bucket_name" {
  description = "Name of the S3 bucket for CodePipeline artifacts"
  type        = string
}

variable "cloudfront_oai_id" {
  description = "CloudFront Origin Access Identity ID for S3 bucket policy"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
