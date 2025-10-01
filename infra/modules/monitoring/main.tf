# CloudWatch billing alarm
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = var.billing_alarm_name
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400" # 24hr
  statistic           = "Maximum"
  threshold           = var.billing_threshold
  alarm_description   = "This metric monitors AWS estimated charges"
  alarm_actions       = var.alarm_actions

  dimensions = {
    Currency = "USD"
  }

  tags = merge(var.tags, {
    Environment = "development"
    Purpose     = "cost-protection"
  })
}

# Lambda error rate alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-contact-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function has errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = var.lambda_function_name
  }
}

# Lambda duration p95 alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "lambda-contact-duration-p95"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "p95"
  threshold           = 3000
  alarm_description   = "Lambda p95 duration exceeds 3s"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = var.lambda_function_name
  }
}

# API Gateway 5XX alarm
resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "apigw-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "API Gateway 5XX errors detected"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiId      = var.api_gateway_id
    Stage      = var.api_gateway_stage
    Resource   = "/contact"
    Method     = "POST"
  }
}

# Performance monitoring dashboard
resource "aws_cloudwatch_dashboard" "performance" {
  dashboard_name = "performance-metrics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p95" }],
            ["AWS/Lambda", "Throttles", "FunctionName", var.lambda_function_name],
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.lambda_function_name]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "Lambda Performance Metrics"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage, { stat = "p95" }],
            ["AWS/ApiGateway", "CacheHitCount", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage],
            ["AWS/ApiGateway", "CacheMissCount", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "API Gateway Performance Metrics"
        }
      }
    ]
  })
}
