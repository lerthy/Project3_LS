output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.contact_api.id
}

output "api_gateway_arn" {
  description = "API Gateway ARN"
  value       = aws_api_gateway_rest_api.contact_api.arn
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage_name}/contact"
}

output "api_key_id" {
  description = "API Gateway API Key ID"
  value       = aws_api_gateway_api_key.contact_api_key.id
}

output "api_key_value" {
  description = "API Gateway API Key Value"
  value       = aws_api_gateway_api_key.contact_api_key.value
  sensitive   = true
}
