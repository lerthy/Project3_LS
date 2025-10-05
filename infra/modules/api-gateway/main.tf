# API Gateway
resource "aws_api_gateway_rest_api" "contact_api" {
  name        = var.api_name
  description = "API for contact form submissions"

  tags = var.tags
}

resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  parent_id   = aws_api_gateway_rest_api.contact_api.root_resource_id
  path_part   = "contact"
}

resource "aws_api_gateway_method" "post_contact" {
  rest_api_id      = aws_api_gateway_rest_api.contact_api.id
  resource_id      = aws_api_gateway_resource.contact_resource.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

# Add OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "options_contact" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.contact_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.post_contact.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# Use mock integration for OPTIONS to avoid Lambda dependency for CORS
resource "aws_api_gateway_integration" "lambda_integration_options" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.options_contact.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.options_contact.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Max-Age"       = true
  }
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.options_contact.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Origin,X-Requested-With'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Max-Age"       = "'86400'"
  }
}

# Method response for POST method (required for CORS)
resource "aws_api_gateway_method_response" "post_contact_200" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.post_contact.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

# Method response for POST method errors
resource "aws_api_gateway_method_response" "post_contact_400" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.post_contact.http_method
  status_code = "400"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_method_response" "post_contact_500" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.post_contact.http_method
  status_code = "500"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

# API Key for authentication
resource "aws_api_gateway_api_key" "contact_api_key" {
  name        = "contact-form-api-key"
  description = "API key for contact form submissions"
  enabled     = true

  tags = merge(var.tags, {
    Name = "contact-form-api-key"
    Type = "api-authentication"
  })
}

# Usage Plan for rate limiting and throttling
resource "aws_api_gateway_usage_plan" "contact_usage_plan" {
  name        = "contact-form-usage-plan"
  description = "Usage plan for contact form API"

  api_stages {
    api_id = aws_api_gateway_rest_api.contact_api.id
    stage  = aws_api_gateway_stage.contact_stage.stage_name
  }

  quota_settings {
    limit  = 1000 # 1000 requests per day
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = 10 # 10 requests per second
    burst_limit = 20 # 20 burst requests
  }

  tags = var.tags
}

# Associate API key with usage plan
resource "aws_api_gateway_usage_plan_key" "contact_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.contact_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.contact_usage_plan.id
}

# Store API key in SSM Parameter Store for frontend access
resource "aws_ssm_parameter" "api_key" {
  name        = "/api-gateway/api_key"
  description = "API key for contact form authentication"
  type        = "SecureString"
  value       = aws_api_gateway_api_key.contact_api_key.value

  tags = merge(var.tags, {
    Name = "api-gateway-key"
    Type = "api-authentication"
  })
}

resource "aws_api_gateway_deployment" "contact_deployment" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.lambda_integration_options,
    aws_api_gateway_integration_response.options_integration_response,
    aws_api_gateway_method_response.post_contact_200,
    aws_api_gateway_method_response.post_contact_400,
    aws_api_gateway_method_response.post_contact_500
  ]

  # Force a new deployment when integrations/methods change
  triggers = {
    redeploy = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage with caching and access logging
resource "aws_api_gateway_stage" "contact_stage" {
  deployment_id = aws_api_gateway_deployment.contact_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  stage_name    = var.stage_name

  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"

  variables = {
    "cacheEnabled" = "true"
    "stage"        = var.stage_name
    "cacheMaxAge"  = "300"
    "throttleRate" = "50"
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId         = "$context.requestId",
      ip                = "$context.identity.sourceIp",
      caller            = "$context.identity.caller",
      user              = "$context.identity.user",
      requestTime       = "$context.requestTime",
      httpMethod        = "$context.httpMethod",
      resourcePath      = "$context.resourcePath",
      status            = "$context.status",
      protocol          = "$context.protocol",
      responseLength    = "$context.responseLength",
      integrationStatus = "$context.integration.status",
      integrationError  = "$context.integrationErrorMessage"
    })
  }
}

# Method settings for caching
resource "aws_api_gateway_method_settings" "contact_cache" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  stage_name  = aws_api_gateway_stage.contact_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled      = true
    logging_level        = "INFO"
    caching_enabled      = true
    cache_ttl_in_seconds = 300 # 5 minutes cache

    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}
# CloudWatch Log Group for API Gateway Access Logs
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/apigw/${aws_api_gateway_rest_api.contact_api.id}/${var.stage_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# WAFv2 Web ACL and association with API Gateway stage
resource "aws_wafv2_web_acl" "apigw_acl" {
  name        = "apigw-basic-acl"
  description = "Basic protections for API Gateway"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "apigw-acl"
    sampled_requests_enabled   = true
  }
  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "apigw_acl_assoc" {
  resource_arn = aws_api_gateway_stage.contact_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.apigw_acl.arn
}

# Ensure CORS headers are present on API Gateway default error responses (4XX/5XX)
resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Origin'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Origin'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
  }
}
