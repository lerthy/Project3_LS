output "hourly_backup_lambda_arn" {
  description = "ARN of the hourly backup Lambda function"
  value       = aws_lambda_function.hourly_backup_orchestrator.arn
}

output "hourly_backup_lambda_name" {
  description = "Name of the hourly backup Lambda function"
  value       = aws_lambda_function.hourly_backup_orchestrator.function_name
}

output "backup_sns_topic_arn" {
  description = "ARN of the backup notifications SNS topic"
  value       = aws_sns_topic.backup_notifications.arn
}

output "rpo_dashboard_url" {
  description = "URL to the RPO monitoring CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.primary_region}#dashboards:name=${aws_cloudwatch_dashboard.rpo_monitoring.dashboard_name}"
}

output "backup_metadata_bucket" {
  description = "S3 bucket name for backup metadata"
  value       = aws_s3_bucket.backup_metadata.bucket
}
