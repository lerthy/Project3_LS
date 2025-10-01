resource "aws_ssm_parameter" "api_gateway_id" {
  name  = "/api-gateway/api_gateway_id"
  type  = "String"
  value = aws_api_gateway_rest_api.contact_api.id

  tags = var.tags
}

resource "aws_ssm_parameter" "api_gateway_arn" {
  name  = "/api-gateway/api_gateway_arn"
  type  = "String"
  value = aws_api_gateway_rest_api.contact_api.arn

  tags = var.tags
}

resource "aws_ssm_parameter" "api_gateway_url" {
  name  = "/api-gateway/api_gateway_url"
  type  = "String"
  value = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage_name}/contact"

  tags = var.tags
}
