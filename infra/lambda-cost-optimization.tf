# Lambda cost optimization with conditional provisioned concurrency
# Only enable provisioned concurrency in production where cold starts matter

# Make provisioned concurrency conditional on environment
resource "aws_lambda_provisioned_concurrency_config" "contact_conditional" {
  count = var.environment == "production" ? 1 : 0
  
  function_name                     = module.lambda.lambda_function_name
  provisioned_concurrent_executions = 2
  qualifier                         = "$LATEST"

  depends_on = [module.lambda]
}

# CloudWatch log group for Lambda with cost-optimized retention
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${module.lambda.lambda_function_name}"
  retention_in_days = var.environment == "production" ? 30 : 7
  tags              = local.common_tags
}

# Lambda function URL for direct invocation (reduces API Gateway costs for simple use cases)
resource "aws_lambda_function_url" "contact_direct" {
  count = var.environment != "production" ? 1 : 0  # Only for non-prod to reduce costs
  
  function_name      = module.lambda.lambda_function_name
  authorization_type = "NONE"
  
  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["POST", "OPTIONS"]
    allow_headers     = ["date", "keep-alive", "content-type"]
    expose_headers    = ["date", "keep-alive"]
    max_age           = 86400
  }
}