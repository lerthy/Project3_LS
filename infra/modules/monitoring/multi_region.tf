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
            [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.primary_rds_id, { "region": var.primary_region } ],
            [ "AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.primary_rds_id, { "region": var.primary_region } ],
            [ "AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.primary_rds_id, { "region": var.primary_region } ],
            [ "AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", var.primary_rds_id, { "region": var.primary_region } ],
            
            # Standby RDS metrics
            [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.standby_rds_id, { "region": var.standby_region } ],
            [ "AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.standby_rds_id, { "region": var.standby_region } ],
            [ "AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.standby_rds_id, { "region": var.standby_region } ],
            [ "AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", var.standby_rds_id, { "region": var.standby_region } ]
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
            [ "AWS/Lambda", "Invocations", "FunctionName", var.primary_lambda_name, { "region": var.primary_region } ],
            [ "AWS/Lambda", "Errors", "FunctionName", var.primary_lambda_name, { "region": var.primary_region } ],
            [ "AWS/Lambda", "Duration", "FunctionName", var.primary_lambda_name, { "region": var.primary_region } ],
            
            # Standby Lambda metrics
            [ "AWS/Lambda", "Invocations", "FunctionName", var.standby_lambda_name, { "region": var.standby_region } ],
            [ "AWS/Lambda", "Errors", "FunctionName", var.standby_lambda_name, { "region": var.standby_region } ],
            [ "AWS/Lambda", "Duration", "FunctionName", var.standby_lambda_name, { "region": var.standby_region } ]
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
            [ "AWS/ApiGateway", "4XXError", "ApiName", var.primary_api_name, { "region": var.primary_region } ],
            [ "AWS/ApiGateway", "5XXError", "ApiName", var.primary_api_name, { "region": var.primary_region } ],
            [ "AWS/ApiGateway", "Latency", "ApiName", var.primary_api_name, { "region": var.primary_region } ],
            
            # Standby API Gateway metrics
            [ "AWS/ApiGateway", "4XXError", "ApiName", var.standby_api_name, { "region": var.standby_region } ],
            [ "AWS/ApiGateway", "5XXError", "ApiName", var.standby_api_name, { "region": var.standby_region } ],
            [ "AWS/ApiGateway", "Latency", "ApiName", var.standby_api_name, { "region": var.standby_region } ]
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
            # Route53 health check metrics
            [ "AWS/Route53", "HealthCheckStatus", "HealthCheckId", var.primary_health_check_id ],
            [ "AWS/Route53", "HealthCheckStatus", "HealthCheckId", var.standby_health_check_id ]
          ]
          period = 60
          region = "us-east-1" # Route53 metrics are always in us-east-1
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

# Lambda function to process alerts
resource "aws_lambda_function" "alert_processor" {
  filename      = "alert_processor.zip"
  function_name = "multi-region-alert-processor"
  role         = aws_iam_role.alert_processor.arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# Composite alarm for overall system health
resource "aws_cloudwatch_composite_alarm" "system_health" {
  alarm_name = "system-health-composite"
  alarm_description = "Composite alarm for overall system health"

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.primary_rds_cpu.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.standby_rds_cpu.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.primary_api_errors.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.standby_api_errors.alarm_name})"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}