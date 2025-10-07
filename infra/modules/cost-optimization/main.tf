# Cost Optimization Module - Resource Scheduling for Non-Production Environments
# Automatically stops/starts resources during off-hours to reduce costs

# EventBridge rules for resource scheduling
resource "aws_cloudwatch_event_rule" "stop_resources" {
  count               = var.environment != "production" ? 1 : 0
  name                = "stop-resources-${var.environment}"
  description         = "Stop non-production resources after business hours"
  schedule_expression = var.stop_schedule # Default: 7 PM UTC (weekdays)

  tags = merge(var.tags, {
    Name    = "stop-resources-${var.environment}"
    Type    = "cost-optimization"
    Purpose = "resource-scheduling"
  })
}

resource "aws_cloudwatch_event_rule" "start_resources" {
  count               = var.environment != "production" ? 1 : 0
  name                = "start-resources-${var.environment}"
  description         = "Start non-production resources before business hours"
  schedule_expression = var.start_schedule # Default: 8 AM UTC (weekdays)

  tags = merge(var.tags, {
    Name    = "start-resources-${var.environment}"
    Type    = "cost-optimization"
    Purpose = "resource-scheduling"
  })
}

# Lambda function for resource scheduling
resource "aws_lambda_function" "resource_scheduler" {
  count         = var.environment != "production" ? 1 : 0
  filename      = data.archive_file.scheduler_zip[0].output_path
  function_name = "resource-scheduler-${var.environment}"
  role          = aws_iam_role.scheduler_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 300

  source_code_hash = data.archive_file.scheduler_zip[0].output_base64sha256

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      RDS_IDENTIFIER  = var.rds_identifier
      LAMBDA_FUNCTION = var.lambda_function_name
    }
  }

  tags = merge(var.tags, {
    Name = "resource-scheduler-${var.environment}"
    Type = "cost-optimization"
  })
}

# Package the Lambda function
data "archive_file" "scheduler_zip" {
  count       = var.environment != "production" ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/scheduler.zip"

  source {
    content = templatefile("${path.module}/scheduler.py", {
      environment = var.environment
    })
    filename = "index.py"
  }
}

# IAM role for the scheduler Lambda
resource "aws_iam_role" "scheduler_role" {
  count = var.environment != "production" ? 1 : 0
  name  = "resource-scheduler-role-${var.environment}"

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

  tags = var.tags
}

# IAM policy for resource management
resource "aws_iam_role_policy" "scheduler_policy" {
  count = var.environment != "production" ? 1 : 0
  name  = "resource-scheduler-policy-${var.environment}"
  role  = aws_iam_role.scheduler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:StopDBInstance",
          "rds:StartDBInstance",
          "rds:DescribeDBInstances"
        ]
        Resource = [
          "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:${var.rds_identifier}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:PutProvisionedConcurrencyConfig",
          "lambda:DeleteProvisionedConcurrencyConfig",
          "lambda:GetProvisionedConcurrencyConfig"
        ]
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_function_name}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.notification_topic_arn
      }
    ]
  })
}

# EventBridge targets for the scheduler Lambda
resource "aws_cloudwatch_event_target" "stop_target" {
  count     = var.environment != "production" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.stop_resources[0].name
  target_id = "StopResourcesTarget"
  arn       = aws_lambda_function.resource_scheduler[0].arn

  input = jsonencode({
    action      = "stop"
    environment = var.environment
  })
}

resource "aws_cloudwatch_event_target" "start_target" {
  count     = var.environment != "production" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.start_resources[0].name
  target_id = "StartResourcesTarget"
  arn       = aws_lambda_function.resource_scheduler[0].arn

  input = jsonencode({
    action      = "start"
    environment = var.environment
  })
}

# Lambda permissions for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_stop" {
  count         = var.environment != "production" ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resource_scheduler[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_resources[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  count         = var.environment != "production" ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resource_scheduler[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_resources[0].arn
}

# CloudWatch alarm for scheduler failures
resource "aws_cloudwatch_metric_alarm" "scheduler_errors" {
  count               = var.environment != "production" ? 1 : 0
  alarm_name          = "resource-scheduler-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Resource scheduler errors in ${var.environment}"
  alarm_actions       = [var.notification_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.resource_scheduler[0].function_name
  }

  tags = var.tags
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
