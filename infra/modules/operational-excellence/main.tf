# ============================================================================
# CI/CD MONITORING AND ALERTING
# ============================================================================

# SNS Topic for CI/CD Notifications
resource "aws_sns_topic" "cicd_notifications" {
  name = "cicd-pipeline-notifications-${var.environment}"

  tags = merge(var.tags, {
    Name    = "cicd-notifications-${var.environment}"
    Type    = "operational-excellence"
    Purpose = "pipeline-monitoring"
  })
}

resource "aws_sns_topic_subscription" "email_notification" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cicd_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Alarms for CodePipeline Failures
resource "aws_cloudwatch_metric_alarm" "infra_pipeline_failures" {
  alarm_name          = "infra-pipeline-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PipelineExecutionFailure"
  namespace           = "AWS/CodePipeline"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Infrastructure pipeline failed in ${var.environment}"
  alarm_actions       = [aws_sns_topic.cicd_notifications.arn]
  ok_actions          = [aws_sns_topic.cicd_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    PipelineName = var.infra_pipeline_name
  }

  tags = merge(var.tags, {
    Name = "infra-pipeline-alarm-${var.environment}"
    Type = "operational-excellence"
  })
}

resource "aws_cloudwatch_metric_alarm" "web_pipeline_failures" {
  alarm_name          = "web-pipeline-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PipelineExecutionFailure"
  namespace           = "AWS/CodePipeline"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Web pipeline failed in ${var.environment}"
  alarm_actions       = [aws_sns_topic.cicd_notifications.arn]
  ok_actions          = [aws_sns_topic.cicd_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    PipelineName = var.web_pipeline_name
  }

  tags = merge(var.tags, {
    Name = "web-pipeline-alarm-${var.environment}"
    Type = "operational-excellence"
  })
}

# CodeBuild Failure Alarms
resource "aws_cloudwatch_metric_alarm" "infra_build_failures" {
  alarm_name          = "infra-build-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedBuilds"
  namespace           = "AWS/CodeBuild"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Infrastructure CodeBuild project failed in ${var.environment}"
  alarm_actions       = [aws_sns_topic.cicd_notifications.arn]
  ok_actions          = [aws_sns_topic.cicd_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ProjectName = var.infra_build_project
  }

  tags = merge(var.tags, {
    Name = "infra-build-alarm-${var.environment}"
    Type = "operational-excellence"
  })
}

resource "aws_cloudwatch_metric_alarm" "web_build_failures" {
  alarm_name          = "web-build-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedBuilds"
  namespace           = "AWS/CodeBuild"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Web CodeBuild project failed in ${var.environment}"
  alarm_actions       = [aws_sns_topic.cicd_notifications.arn]
  ok_actions          = [aws_sns_topic.cicd_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ProjectName = var.web_build_project
  }

  tags = merge(var.tags, {
    Name = "web-build-alarm-${var.environment}"
    Type = "operational-excellence"
  })
}

# Build Duration Monitoring (for performance tracking)
resource "aws_cloudwatch_metric_alarm" "build_duration_warning" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "build-duration-warning-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/CodeBuild"
  period              = "300"
  statistic           = "Average"
  threshold           = "600" # 10 minutes
  alarm_description   = "Build taking longer than expected (>10 minutes)"
  alarm_actions       = [aws_sns_topic.cicd_notifications.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ProjectName = var.infra_build_project
  }

  tags = merge(var.tags, {
    Name = "build-duration-warning-${var.environment}"
    Type = "operational-excellence"
  })
}

# ============================================================================
# MANUAL APPROVAL GATES
# ============================================================================

# SNS Topic for Manual Approvals
resource "aws_sns_topic" "manual_approval" {
  name = "manual-approval-notifications-${var.environment}"

  tags = merge(var.tags, {
    Name    = "manual-approval-${var.environment}"
    Type    = "operational-excellence"
    Purpose = "deployment-approval"
  })
}

resource "aws_sns_topic_subscription" "approval_email" {
  count     = var.approval_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.manual_approval.arn
  protocol  = "email"
  endpoint  = var.approval_email
}

# IAM Role for CodePipeline Manual Approval
resource "aws_iam_role" "approval_role" {
  name = "codepipeline-approval-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "approval-role-${var.environment}"
    Type = "operational-excellence"
  })
}

resource "aws_iam_role_policy" "approval_policy" {
  name = "approval-policy-${var.environment}"
  role = aws_iam_role.approval_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.manual_approval.arn
      }
    ]
  })
}

# ============================================================================
# OPERATIONAL DASHBOARDS
# ============================================================================

resource "aws_cloudwatch_dashboard" "operational_excellence" {
  dashboard_name = "operational-excellence-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSuccess", "PipelineName", var.infra_pipeline_name],
            [".", "PipelineExecutionFailure", ".", "."],
            [".", "PipelineExecutionSuccess", "PipelineName", var.web_pipeline_name],
            [".", "PipelineExecutionFailure", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Pipeline Success/Failure Rate"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CodeBuild", "Duration", "ProjectName", var.infra_build_project],
            [".", ".", ".", var.web_build_project]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Build Duration (seconds)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '/aws/codebuild/${var.infra_build_project}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region = data.aws_region.current.name
          title  = "Recent Build Errors"
          view   = "table"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."],
            [".", "Invocations", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Function Health"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", var.api_gateway_name],
            [".", "5XXError", ".", "."],
            [".", "Latency", ".", "."],
            [".", "Count", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "API Gateway Health"
        }
      }
    ]
  })
}

# Deployment Health Dashboard
resource "aws_cloudwatch_dashboard" "deployment_health" {
  dashboard_name = "deployment-health-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CodePipeline", "ActionExecutionSuccess", "PipelineName", var.infra_pipeline_name, "ActionName", "Deploy"],
            [".", "ActionExecutionFailure", ".", ".", ".", "."],
            [".", "ActionExecutionSuccess", "PipelineName", var.web_pipeline_name, "ActionName", "Deploy"],
            [".", "ActionExecutionFailure", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Deployment Success Rate"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CodePipeline", "ActionExecutionDuration", "PipelineName", var.infra_pipeline_name, "ActionName", "Deploy"],
            [".", ".", "PipelineName", var.web_pipeline_name, "ActionName", "Deploy"]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Deployment Duration"
        }
      },
      {
        type   = "number"
        x      = 0
        y      = 6
        width  = 6
        height = 3
        properties = {
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSuccess", "PipelineName", var.infra_pipeline_name]
          ]
          period = 86400
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Daily Infra Deployments"
        }
      },
      {
        type   = "number"
        x      = 6
        y      = 6
        width  = 6
        height = 3
        properties = {
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSuccess", "PipelineName", var.web_pipeline_name]
          ]
          period = 86400
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Daily Web Deployments"
        }
      }
    ]
  })
}

# Deployment Health Check Alarm
resource "aws_cloudwatch_metric_alarm" "deployment_health_check" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "deployment-health-check-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Lambda function not receiving traffic after deployment"
  alarm_actions       = [aws_sns_topic.cicd_notifications.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = merge(var.tags, {
    Name = "deployment-health-check-${var.environment}"
    Type = "operational-excellence"
  })
}

# ============================================================================
# INFRASTRUCTURE DRIFT DETECTION
# ============================================================================

# Lambda function for drift detection
# ============================================================================
# INFRASTRUCTURE DRIFT DETECTION
# ============================================================================

# SNS Topic for drift alerts
resource "aws_sns_topic" "drift_alerts" {
  name = "${var.environment}-drift-alerts"

  tags = merge(var.tags, {
    Name = "${var.environment}-drift-alerts"
    Type = "operational-excellence"
  })
}

resource "aws_sns_topic_subscription" "drift_alerts_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.drift_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Log Group for drift detection Lambda
resource "aws_cloudwatch_log_group" "drift_detection" {
  name              = "/aws/lambda/${var.environment}-drift-detection"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${var.environment}-drift-detection-logs"
    Type = "operational-excellence"
  })
}

# IAM Role for drift detection Lambda
resource "aws_iam_role" "drift_detection" {
  name = "${var.environment}-drift-detection-role"

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

  tags = merge(var.tags, {
    Name = "${var.environment}-drift-detection-role"
    Type = "operational-excellence"
  })
}

resource "aws_iam_role_policy" "drift_detection" {
  name = "${var.environment}-drift-detection-policy"
  role = aws_iam_role.drift_detection.id

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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.environment}-drift-detection:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.terraform_state_bucket}/${var.terraform_state_key}"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.drift_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Custom/InfrastructureDrift"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "drift_detection_policy" {
  role       = aws_iam_role.drift_detection_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create Lambda deployment package
data "archive_file" "drift_detection" {
  type        = "zip"
  source_file = "${path.module}/drift_detection.py"
  output_path = "${path.module}/drift_detection.zip"
}

resource "aws_lambda_function" "drift_detection" {
  filename         = data.archive_file.drift_detection.output_path
  function_name    = "${var.environment}-drift-detection"
  role             = aws_iam_role.drift_detection_role.arn
  handler          = "drift_detection.handler"
  runtime          = "python3.9"
  timeout          = 300
  memory_size      = 256
  source_code_hash = data.archive_file.drift_detection.output_base64sha256

  environment {
    variables = {
      TERRAFORM_STATE_BUCKET = var.terraform_state_bucket
      TERRAFORM_STATE_KEY    = var.terraform_state_key
      SNS_TOPIC_ARN          = aws_sns_topic.drift_alerts.arn
      ENVIRONMENT            = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.drift_detection_policy,
    aws_cloudwatch_log_group.drift_detection,
  ]

  tags = merge(var.tags, {
    Name = "${var.environment}-drift-detection"
    Type = "operational-excellence"
  })
}

# IAM Role for Drift Detection Lambda
resource "aws_iam_role" "drift_detection_role" {
  name = "drift-detection-role-${var.environment}"

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

  tags = merge(var.tags, {
    Name = "drift-detection-role-${var.environment}"
    Type = "operational-excellence"
  })
}

# IAM Policy for Drift Detection
resource "aws_iam_role_policy" "drift_detection_policy" {
  name = "drift-detection-policy-${var.environment}"
  role = aws_iam_role.drift_detection_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:*:table/terraform-*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.cicd_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "s3:List*",
          "s3:Get*",
          "lambda:List*",
          "lambda:Get*",
          "apigateway:GET",
          "rds:Describe*",
          "cloudfront:List*",
          "cloudfront:Get*"
        ]
        Resource = "*"
      }
    ]
  })
}

