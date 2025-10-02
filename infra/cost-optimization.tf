# Additional Cost Optimization Resources

# Service-specific cost alarms
resource "aws_cloudwatch_metric_alarm" "s3_costs" {
  alarm_name          = "s3-monthly-costs-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.environment == "production" ? "50" : "10"
  alarm_description   = "S3 monthly costs exceeded threshold"
  alarm_actions       = []

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonS3"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_costs" {
  alarm_name          = "lambda-monthly-costs-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.environment == "production" ? "20" : "5"
  alarm_description   = "Lambda monthly costs exceeded threshold"
  alarm_actions       = []

  dimensions = {
    Currency    = "USD"
    ServiceName = "AWSLambda"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_costs" {
  alarm_name          = "rds-monthly-costs-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.environment == "production" ? "100" : "25"
  alarm_description   = "RDS monthly costs exceeded threshold"
  alarm_actions       = []

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonRDS"
  }

  tags = local.common_tags
}

# Cost optimization dashboard
resource "aws_cloudwatch_dashboard" "cost_optimization" {
  dashboard_name = "cost-optimization-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3", "Currency", "USD"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AWSLambda", "Currency", "USD"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonRDS", "Currency", "USD"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonCloudFront", "Currency", "USD"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonApiGateway", "Currency", "USD"]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1" # Billing metrics are only in us-east-1
          title  = "Service Costs (Daily)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", module.s3.website_bucket_name, "StorageType", "StandardStorage"],
            ["AWS/S3", "NumberOfObjects", "BucketName", module.s3.website_bucket_name, "StorageType", "AllStorageTypes"]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Storage Metrics"
        }
      }
    ]
  })
}