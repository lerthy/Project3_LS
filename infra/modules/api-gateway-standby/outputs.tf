# API Gateway Outputs
output "rest_api_id" {
  description = "ID of the API Gateway REST API in standby region"
  value       = aws_api_gateway_rest_api.api.id
}

output "rest_api_arn" {
  description = "ARN of the API Gateway REST API in standby region"
  value       = aws_api_gateway_rest_api.api.arn
}

output "api_endpoint" {
  description = "URL of the API Gateway endpoint in standby region"
  value       = "${aws_api_gateway_stage.api.invoke_url}${aws_api_gateway_resource.contact.path}"
}

output "stage_name" {
  description = "Name of the API Gateway stage in standby region"
  value       = aws_api_gateway_stage.api.stage_name
}

output "stage_arn" {
  description = "ARN of the API Gateway stage in standby region"
  value       = aws_api_gateway_stage.api.arn
}

output "execution_arn" {
  description = "Execution ARN to be used in Lambda permission in standby region"
  value       = aws_api_gateway_rest_api.api.execution_arn
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for API Gateway access logs"
  value       = aws_cloudwatch_log_group.api.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for API Gateway access logs"
  value       = aws_cloudwatch_log_group.api.name
}