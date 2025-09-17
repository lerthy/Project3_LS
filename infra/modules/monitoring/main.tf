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
