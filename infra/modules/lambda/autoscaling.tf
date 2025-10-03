# Lambda Auto Scaling Configuration - target the alias for provisioned concurrency
resource "aws_appautoscaling_target" "lambda_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "function:${aws_lambda_function.contact.function_name}:${aws_lambda_alias.contact_live.name}"
  scalable_dimension = "lambda:function:ProvisionedConcurrency"
  service_namespace  = "lambda"
  
  depends_on = [aws_lambda_alias.contact_live]
}

# Scale based on utilization
resource "aws_appautoscaling_policy" "lambda_utilization" {
  name               = "lambda-utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.lambda_target.resource_id
  scalable_dimension = aws_appautoscaling_target.lambda_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.lambda_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "LambdaProvisionedConcurrencyUtilization"
    }
    target_value = 0.75
  }
}

# CloudWatch alarms for Lambda monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${aws_lambda_function.contact.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors lambda function errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.contact.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${aws_lambda_function.contact.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000"  # 10 seconds
  alarm_description   = "This metric monitors lambda function duration"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.contact.function_name
  }
}