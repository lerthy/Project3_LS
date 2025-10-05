# CloudWatch dashboard for multi-region monitoring
resource "aws_cloudwatch_dashboard" "multi_region" {
  dashboard_name = "multi-region-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            # Primary RDS metrics
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.primary_rds_id, { "region" : var.primary_region }],
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.primary_rds_id, { "region" : var.primary_region }],
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.primary_rds_id, { "region" : var.primary_region }],
            ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", var.primary_rds_id, { "region" : var.primary_region }],

            # Standby RDS metrics
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.standby_rds_id, { "region" : var.standby_region }],
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.standby_rds_id, { "region" : var.standby_region }],
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.standby_rds_id, { "region" : var.standby_region }],
            ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", var.standby_rds_id, { "region" : var.standby_region }]
          ]
          period = 300
          region = var.primary_region
          title  = "RDS Metrics (Both Regions)"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            # Primary Lambda metrics
            ["AWS/Lambda", "Invocations", "FunctionName", var.primary_lambda_name, { "region" : var.primary_region }],
            ["AWS/Lambda", "Errors", "FunctionName", var.primary_lambda_name, { "region" : var.primary_region }],
            ["AWS/Lambda", "Duration", "FunctionName", var.primary_lambda_name, { "region" : var.primary_region }],

            # Standby Lambda metrics
            ["AWS/Lambda", "Invocations", "FunctionName", var.standby_lambda_name, { "region" : var.standby_region }],
            ["AWS/Lambda", "Errors", "FunctionName", var.standby_lambda_name, { "region" : var.standby_region }],
            ["AWS/Lambda", "Duration", "FunctionName", var.standby_lambda_name, { "region" : var.standby_region }]
          ]
          period = 300
          region = var.primary_region
          title  = "Lambda Metrics (Both Regions)"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            # Primary API Gateway metrics
            ["AWS/ApiGateway", "4XXError", "ApiName", var.primary_api_name, { "region" : var.primary_region }],
            ["AWS/ApiGateway", "5XXError", "ApiName", var.primary_api_name, { "region" : var.primary_region }],
            ["AWS/ApiGateway", "Latency", "ApiName", var.primary_api_name, { "region" : var.primary_region }],

            # Standby API Gateway metrics
            ["AWS/ApiGateway", "4XXError", "ApiName", var.standby_api_name, { "region" : var.standby_region }],
            ["AWS/ApiGateway", "5XXError", "ApiName", var.standby_api_name, { "region" : var.standby_region }],
            ["AWS/ApiGateway", "Latency", "ApiName", var.standby_api_name, { "region" : var.standby_region }]
          ]
          period = 300
          region = var.primary_region
          title  = "API Gateway Metrics (Both Regions)"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            # Route53 health check metrics (only if health check IDs are provided)
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", var.primary_health_check_id != "" ? var.primary_health_check_id : "example-health-check-1"],
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", var.standby_health_check_id != "" ? var.standby_health_check_id : "example-health-check-2"]
          ]
          period = 60
          region = "eu-north-1" # Route53 metrics are always in eu-north-1
          title  = "Route53 Health Check Status"
        }
      }
    ]
  })
}

# SNS topic for alarms
resource "aws_sns_topic" "alerts" {
  name = "multi-region-alerts"
}

# Multi-region monitoring resources

# IAM role for alert processor Lambda
resource "aws_iam_role" "alert_processor" {
  name = "alert-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alert_processor_basic" {
  role       = aws_iam_role.alert_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function to process alerts
resource "aws_lambda_function" "alert_processor" {
  filename      = "${path.module}/alert_processor.zip"
  function_name = "multi-region-alert-processor"
  role          = aws_iam_role.alert_processor.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# Primary RDS CPU alarm
resource "aws_cloudwatch_metric_alarm" "primary_rds_cpu" {
  count = var.primary_rds_id != "" ? 1 : 0

  alarm_name          = "primary-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors primary RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.primary_rds_id
  }
}

# Standby RDS CPU alarm
resource "aws_cloudwatch_metric_alarm" "standby_rds_cpu" {
  count = var.standby_rds_id != "" ? 1 : 0

  alarm_name          = "standby-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors standby RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.standby_rds_id
  }
}

# Primary API errors alarm
resource "aws_cloudwatch_metric_alarm" "primary_api_errors" {
  count = var.primary_api_name != "" ? 1 : 0

  alarm_name          = "primary-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors primary API Gateway 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = var.primary_api_name
  }
}

# Standby API errors alarm  
resource "aws_cloudwatch_metric_alarm" "standby_api_errors" {
  count = var.standby_api_name != "" ? 1 : 0

  alarm_name          = "standby-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors standby API Gateway 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = var.standby_api_name
  }
}

# Composite alarm for overall system health
resource "aws_cloudwatch_composite_alarm" "system_health" {
  alarm_name        = "system-health-composite"
  alarm_description = "Composite alarm for overall system health"

  alarm_rule = join(" OR ", compact([
    var.primary_rds_id != "" ? "ALARM(${aws_cloudwatch_metric_alarm.primary_rds_cpu[0].alarm_name})" : "",
    var.standby_rds_id != "" ? "ALARM(${aws_cloudwatch_metric_alarm.standby_rds_cpu[0].alarm_name})" : "",
    var.primary_api_name != "" ? "ALARM(${aws_cloudwatch_metric_alarm.primary_api_errors[0].alarm_name})" : "",
    var.standby_api_name != "" ? "ALARM(${aws_cloudwatch_metric_alarm.standby_api_errors[0].alarm_name})" : ""
  ]))

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}