variable "billing_alarm_name" {
  description = "Name of the billing alarm"
  type        = string
  default     = "billing-alarm-5-usd"
}

variable "billing_threshold" {
  description = "Billing threshold in USD"
  type        = string
  default     = "5"
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm is triggered"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
