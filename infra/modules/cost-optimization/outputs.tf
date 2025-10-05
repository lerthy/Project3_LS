output "scheduler_lambda_arn" {
  description = "ARN of the resource scheduler Lambda function"
  value       = var.environment != "production" ? aws_lambda_function.resource_scheduler[0].arn : null
}

output "scheduler_function_name" {
  description = "Name of the resource scheduler Lambda function"
  value       = var.environment != "production" ? aws_lambda_function.resource_scheduler[0].function_name : null
}

output "stop_schedule_rule_arn" {
  description = "ARN of the stop resources EventBridge rule"
  value       = var.environment != "production" ? aws_cloudwatch_event_rule.stop_resources[0].arn : null
}

output "start_schedule_rule_arn" {
  description = "ARN of the start resources EventBridge rule"
  value       = var.environment != "production" ? aws_cloudwatch_event_rule.start_resources[0].arn : null
}

output "cost_savings_estimate" {
  description = "Estimated daily cost savings from resource scheduling"
  value = var.environment != "production" ? {
    rds_daily_savings      = "$2-10 (12 hours off-time)"
    lambda_daily_savings   = "$1-3 (provisioned concurrency removed)"
    total_monthly_estimate = "$90-390 (business hours only)"
  } : null
}
