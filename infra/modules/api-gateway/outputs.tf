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
