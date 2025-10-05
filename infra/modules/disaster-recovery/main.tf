# Disaster Recovery Automation Module
# Implements automated failover orchestration to meet 4-hour RTO

# SNS Topic for disaster recovery notifications
resource "aws_sns_topic" "disaster_recovery" {
  name = "disaster-recovery-${var.environment}"

  tags = merge(var.tags, {
    Name = "disaster-recovery-notifications"
    Type = "disaster-recovery"
  })
}

resource "aws_sns_topic_subscription" "dr_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.disaster_recovery.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# IAM Role for Disaster Recovery Lambda
resource "aws_iam_role" "dr_lambda_role" {
  name = "disaster-recovery-lambda-role-${var.environment}"

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

# IAM Policy for Disaster Recovery Lambda
resource "aws_iam_policy" "dr_lambda_policy" {
  name = "disaster-recovery-lambda-policy-${var.environment}"

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
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:PromoteReadReplica",
          "rds:CreateDBSnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetHealthCheck",
          "route53:UpdateHealthCheck",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.disaster_recovery.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "dr_lambda_policy_attachment" {
  role       = aws_iam_role.dr_lambda_role.name
  policy_arn = aws_iam_policy.dr_lambda_policy.arn
}

# Lambda function for disaster recovery orchestration
resource "aws_lambda_function" "disaster_recovery_orchestrator" {
  filename         = "${path.module}/disaster_recovery.zip"
  function_name    = "disaster-recovery-orchestrator-${var.environment}"
  role             = aws_iam_role.dr_lambda_role.arn
  handler          = "disaster_recovery.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900 # 15 minutes
  memory_size      = 512
  source_code_hash = filebase64sha256("${path.module}/disaster_recovery.zip")

  environment {
    variables = {
      ENVIRONMENT            = var.environment
      PRIMARY_REGION         = var.primary_region
      STANDBY_REGION         = var.standby_region
      PRIMARY_RDS_IDENTIFIER = var.primary_rds_identifier
      STANDBY_RDS_IDENTIFIER = var.standby_rds_identifier
      ROUTE53_ZONE_ID        = var.route53_zone_id
      ROUTE53_RECORD_NAME    = var.route53_record_name
      SNS_TOPIC_ARN          = aws_sns_topic.disaster_recovery.arn
      PRIMARY_LAMBDA_NAME    = var.primary_lambda_name
      STANDBY_LAMBDA_NAME    = var.standby_lambda_name
    }
  }

  tags = merge(var.tags, {
    Name = "disaster-recovery-orchestrator"
    Type = "disaster-recovery"
  })

  depends_on = [
    aws_iam_role_policy_attachment.dr_lambda_policy_attachment
  ]
}

# CloudWatch Event Rule to trigger on Route53 health check failures
resource "aws_cloudwatch_event_rule" "primary_region_failure" {
  name        = "primary-region-failure-${var.environment}"
  description = "Triggers when primary region health check fails"

  event_pattern = jsonencode({
    source      = ["aws.route53"]
    detail-type = ["Route 53 Health Check Failure"]
    detail = {
      status          = ["FAILURE"]
      health-check-id = [var.primary_health_check_id]
    }
  })

  tags = var.tags
}

# CloudWatch Event Target to invoke Lambda on failure
resource "aws_cloudwatch_event_target" "dr_lambda_target" {
  rule      = aws_cloudwatch_event_rule.primary_region_failure.name
  target_id = "DisasterRecoveryLambdaTarget"
  arn       = aws_lambda_function.disaster_recovery_orchestrator.arn

  input = jsonencode({
    action = "initiate_failover"
    source = "route53_health_check"
  })
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_events" {
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.disaster_recovery_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.primary_region_failure.arn
}

# CloudWatch Alarms for DR monitoring
resource "aws_cloudwatch_metric_alarm" "dr_lambda_errors" {
  alarm_name          = "disaster-recovery-lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Disaster recovery Lambda function has errors"
  alarm_actions       = [aws_sns_topic.disaster_recovery.arn]
  ok_actions          = [aws_sns_topic.disaster_recovery.arn]

  dimensions = {
    FunctionName = aws_lambda_function.disaster_recovery_orchestrator.function_name
  }

  tags = var.tags
}

# Custom CloudWatch metric for DR status
resource "aws_cloudwatch_log_metric_filter" "dr_status_metric" {
  name           = "disaster-recovery-status-${var.environment}"
  log_group_name = "/aws/lambda/${aws_lambda_function.disaster_recovery_orchestrator.function_name}"
  pattern        = "[timestamp, request_id, level=STATUS, message]"

  metric_transformation {
    name      = "DisasterRecoveryStatus"
    namespace = "Project3/DisasterRecovery"
    value     = "1"
  }
}

# Dashboard for DR monitoring
resource "aws_cloudwatch_dashboard" "disaster_recovery" {
  dashboard_name = "disaster-recovery-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.disaster_recovery_orchestrator.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.disaster_recovery_orchestrator.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.disaster_recovery_orchestrator.function_name]
          ]
          period = 300
          stat   = "Average"
          region = var.primary_region
          title  = "Disaster Recovery Lambda Metrics"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Project3/DisasterRecovery", "DisasterRecoveryStatus"]
          ]
          period = 300
          stat   = "Sum"
          region = var.primary_region
          title  = "DR Orchestration Events"
        }
      }
    ]
  })
}
