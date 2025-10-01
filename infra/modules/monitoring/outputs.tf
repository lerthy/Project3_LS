output "billing_alarm_arn" {
  description = "ARN of the billing alarm"
  value       = aws_cloudwatch_metric_alarm.billing_alarm.arn
}

output "billing_alarm_name" {
  description = "Name of the billing alarm"
  value       = aws_cloudwatch_metric_alarm.billing_alarm.alarm_name
}
