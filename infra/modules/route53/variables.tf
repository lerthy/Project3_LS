variable "primary_api_dns" {
  description = "DNS name of the primary API endpoint"
  type        = string
}

variable "standby_api_dns" {
  description = "DNS name of the standby API endpoint"
  type        = string
}

variable "primary_api_ip" {
  description = "IP address of the primary API endpoint"
  type        = string
}

variable "standby_api_ip" {
  description = "IP address of the standby API endpoint"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for failover record"
  type        = string
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}
