# ============================================================================
# CI/CD MONITORING AND ALERTING
# ============================================================================

# SNS Topic for CI/CD Notifications
resource "aws_sns_topic" "cicd_notifications" {
  name = "cicd-pipeline-notifications-${var.environment}"
  
  tags = merge(var.tags, {
    Name = "cicd-notifications-${var.environment}"
    Type = "operational-excellence"
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
    Name = "manual-approval-${var.environment}"
    Type = "operational-excellence"
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
          query   = "SOURCE '/aws/codebuild/${var.infra_build_project}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region  = data.aws_region.current.name
          title   = "Recent Build Errors"
          view    = "table"
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

# ============================================================================
# INFRASTRUCTURE DRIFT DETECTION
# ============================================================================

# IAM Role for Drift Detection Lambda
resource "aws_iam_role" "drift_detector_role" {
  name = "drift-detector-role-${var.environment}"

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
    Name = "drift-detector-role-${var.environment}"
    Type = "operational-excellence"
  })
}

resource "aws_iam_role_policy" "drift_detector_policy" {
  name = "drift-detector-policy-${var.environment}"
  role = aws_iam_role.drift_detector_role.id

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
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.terraform_state_bucket}/${var.terraform_state_key}"
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
          "ec2:Describe*",
          "rds:Describe*",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning", 
          "s3:GetBucketEncryption",
          "lambda:GetFunction",
          "apigateway:GET",
          "cloudfront:GetDistribution"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Event Rule to trigger drift detection
resource "aws_cloudwatch_event_rule" "drift_detection_schedule" {
  name                = "terraform-drift-detection-${var.environment}"
  description         = "Trigger drift detection daily"
  schedule_expression = var.environment == "production" ? "cron(0 9 * * ? *)" : "cron(0 18 * * ? *)" # Production: 9 AM UTC, Others: 6 PM UTC

  tags = merge(var.tags, {
    Name = "drift-detection-schedule-${var.environment}"
    Type = "operational-excellence"
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