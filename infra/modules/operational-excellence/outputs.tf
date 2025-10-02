# ============================================================================
# OPERATIONAL EXCELLENCE OUTPUTS
# ============================================================================

output "cicd_notification_topic_arn" {
  description = "ARN of the SNS topic for CI/CD notifications"
  value       = aws_sns_topic.cicd_notifications.arn
}

output "manual_approval_topic_arn" {
  description = "ARN of the SNS topic for manual approval notifications"
  value       = aws_sns_topic.manual_approval.arn
}

output "approval_role_arn" {
  description = "ARN of the IAM role for manual approvals"
  value       = aws_iam_role.approval_role.arn
}

# Note: drift_detector_role removed - resource doesn't exist

output "operational_dashboard_url" {
  description = "URL of the operational excellence dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.operational_excellence.dashboard_name}"
}

output "deployment_dashboard_url" {
  description = "URL of the deployment health dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.deployment_health.dashboard_name}"
}

# Alarm Names for Reference
output "infra_pipeline_alarm_name" {
  description = "Name of the infrastructure pipeline failure alarm"
  value       = aws_cloudwatch_metric_alarm.infra_pipeline_failures.alarm_name
}

output "web_pipeline_alarm_name" {
  description = "Name of the web pipeline failure alarm"
  value       = aws_cloudwatch_metric_alarm.web_pipeline_failures.alarm_name
}

output "infra_build_alarm_name" {
  description = "Name of the infrastructure build failure alarm"
  value       = aws_cloudwatch_metric_alarm.infra_build_failures.alarm_name
}

output "web_build_alarm_name" {
  description = "Name of the web build failure alarm"  
  value       = aws_cloudwatch_metric_alarm.web_build_failures.alarm_name
}

# Note: drift_detection_schedule removed - resource doesn't exist