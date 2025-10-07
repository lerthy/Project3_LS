# Provider configuration for standby region
provider "aws" {
  alias  = "standby"
  region = var.region
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  provider = aws.standby

  name = "${var.environment}-contact-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# API Gateway resource
resource "aws_api_gateway_resource" "contact" {
  provider = aws.standby

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "contact"
}

# API Gateway method
resource "aws_api_gateway_method" "contact_post" {
  provider = aws.standby

  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.contact.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway integration with Lambda
resource "aws_api_gateway_integration" "lambda" {
  provider = aws.standby

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.contact.id
  http_method = aws_api_gateway_method.contact_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "api" {
  provider = aws.standby

  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway stage
resource "aws_api_gateway_stage" "api" {
  provider = aws.standby

  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  tags = var.tags
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api" {
  provider = aws.standby

  name              = "/aws/apigateway/${var.environment}-contact-api-standby"
  retention_in_days = 14

  tags = var.tags
}

# CloudWatch alarms for API monitoring
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  provider = aws.standby

  alarm_name          = "${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "API Gateway 5XX error rate is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.api.name
    Stage   = aws_api_gateway_stage.api.stage_name
  }
}

# API Gateway CloudWatch Logs role for standby region
resource "aws_iam_role" "api_gateway_cloudwatch_role_standby" {
  provider = aws.standby
  name     = "api-gateway-cloudwatch-role-standby-project3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_policy_standby" {
  provider   = aws.standby
  role       = aws_iam_role.api_gateway_cloudwatch_role_standby.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set the API Gateway account configuration to use the CloudWatch Logs role in standby region
resource "aws_api_gateway_account" "api_gateway_account_standby" {
  provider            = aws.standby
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role_standby.arn
}