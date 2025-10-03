output "disaster_recovery_lambda_arn" {
  description = "ARN of the disaster recovery orchestrator Lambda function"
  value       = aws_lambda_function.disaster_recovery_orchestrator.arn
}

output "disaster_recovery_lambda_name" {
  description = "Name of the disaster recovery orchestrator Lambda function"
  value       = aws_lambda_function.disaster_recovery_orchestrator.function_name
}

output "disaster_recovery_sns_topic_arn" {
  description = "ARN of the disaster recovery SNS topic"
  value       = aws_sns_topic.disaster_recovery.arn
}

output "disaster_recovery_dashboard_url" {
  description = "URL to the disaster recovery CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.primary_region}#dashboards:name=${aws_cloudwatch_dashboard.disaster_recovery.dashboard_name}"
}
