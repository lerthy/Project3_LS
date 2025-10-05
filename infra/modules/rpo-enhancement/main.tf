# RPO Enhancement Module
# Implements hourly backups and continuous data protection to meet 1-hour RPO

# SNS Topic for backup notifications
resource "aws_sns_topic" "backup_notifications" {
  name = "backup-notifications-${var.environment}"

  tags = merge(var.tags, {
    Name = "backup-notifications"
    Type = "rpo-enhancement"
  })
}

resource "aws_sns_topic_subscription" "backup_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# IAM Role for Backup Lambda
resource "aws_iam_role" "backup_lambda_role" {
  name = "rpo-backup-lambda-role-${var.environment}"

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

# IAM Policy for Backup Lambda
resource "aws_iam_policy" "backup_lambda_policy" {
  name = "rpo-backup-lambda-policy-${var.environment}"

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
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBInstances",
          "rds:ModifyDBSnapshotAttribute",
          "rds:CopyDBSnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dms:DescribeReplicationTasks",
          "dms:DescribeReplicationInstances",
          "dms:StartReplicationTask",
          "dms:StopReplicationTask",
          "dms:ModifyReplicationTask"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.backup_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.backup_bucket_name}",
          "arn:aws:s3:::${var.backup_bucket_name}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_lambda_policy_attachment" {
  role       = aws_iam_role.backup_lambda_role.name
  policy_arn = aws_iam_policy.backup_lambda_policy.arn
}

# Lambda function for hourly backups
resource "aws_lambda_function" "hourly_backup_orchestrator" {
  filename         = "${path.module}/hourly_backup.zip"
  function_name    = "hourly-backup-orchestrator-${var.environment}"
  role             = aws_iam_role.backup_lambda_role.arn
  handler          = "hourly_backup.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900 # 15 minutes
  memory_size      = 256
  source_code_hash = filebase64sha256("${path.module}/hourly_backup.zip")

  environment {
    variables = {
      ENVIRONMENT            = var.environment
      PRIMARY_RDS_IDENTIFIER = var.primary_rds_identifier
      STANDBY_RDS_IDENTIFIER = var.standby_rds_identifier
      PRIMARY_REGION         = var.primary_region
      STANDBY_REGION         = var.standby_region
      BACKUP_RETENTION_HOURS = var.backup_retention_hours
      SNS_TOPIC_ARN          = aws_sns_topic.backup_notifications.arn
      BACKUP_BUCKET_NAME     = var.backup_bucket_name
      DMS_TASK_ARN           = var.dms_task_arn
    }
  }

  tags = merge(var.tags, {
    Name = "hourly-backup-orchestrator"
    Type = "rpo-enhancement"
  })

  depends_on = [
    aws_iam_role_policy_attachment.backup_lambda_policy_attachment
  ]
}

# CloudWatch Events Rule for hourly backups
resource "aws_cloudwatch_event_rule" "hourly_backup_schedule" {
  name                = "hourly-backup-schedule-${var.environment}"
  description         = "Triggers hourly RDS snapshots for 1-hour RPO"
  schedule_expression = "rate(1 hour)" # Every hour
  state               = var.environment == "production" ? "ENABLED" : "DISABLED"

  tags = var.tags
}

# CloudWatch Event Target for hourly backups
resource "aws_cloudwatch_event_target" "backup_lambda_target" {
  rule      = aws_cloudwatch_event_rule.hourly_backup_schedule.name
  target_id = "HourlyBackupLambdaTarget"
  arn       = aws_lambda_function.hourly_backup_orchestrator.arn

  input = jsonencode({
    action = "create_hourly_backup"
    source = "cloudwatch_schedule"
  })
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_backup_events" {
  statement_id  = "AllowExecutionFromCloudWatchBackupEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hourly_backup_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_backup_schedule.arn
}

# CloudWatch Events Rule for backup cleanup (daily)
resource "aws_cloudwatch_event_rule" "backup_cleanup_schedule" {
  name                = "backup-cleanup-schedule-${var.environment}"
  description         = "Daily cleanup of old hourly backups"
  schedule_expression = "cron(0 2 * * ? *)" # 2 AM daily

  tags = var.tags
}

# CloudWatch Event Target for backup cleanup
resource "aws_cloudwatch_event_target" "cleanup_lambda_target" {
  rule      = aws_cloudwatch_event_rule.backup_cleanup_schedule.name
  target_id = "BackupCleanupLambdaTarget"
  arn       = aws_lambda_function.hourly_backup_orchestrator.arn

  input = jsonencode({
    action = "cleanup_old_backups"
    source = "cloudwatch_schedule"
  })
}

# Lambda permission for cleanup events
resource "aws_lambda_permission" "allow_cloudwatch_cleanup_events" {
  statement_id  = "AllowExecutionFromCloudWatchCleanupEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hourly_backup_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_cleanup_schedule.arn
}

# CloudWatch Alarms for backup monitoring
resource "aws_cloudwatch_metric_alarm" "backup_failures" {
  alarm_name          = "hourly-backup-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 3600 # 1 hour
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Hourly backup Lambda function has errors"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]
  ok_actions          = [aws_sns_topic.backup_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.hourly_backup_orchestrator.function_name
  }

  tags = var.tags
}

# CloudWatch Alarm for missing backups
resource "aws_cloudwatch_metric_alarm" "missing_backups" {
  alarm_name          = "missing-hourly-backups-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HourlyBackupSuccess"
  namespace           = "Project3/RPO"
  period              = 7200 # 2 hours
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "No successful hourly backups in the last 2 hours"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]
  treat_missing_data  = "breaching"

  tags = var.tags
}

# CloudWatch Alarm for DMS replication lag
resource "aws_cloudwatch_metric_alarm" "dms_replication_lag" {
  count               = var.dms_task_arn != "" ? 1 : 0
  alarm_name          = "dms-replication-lag-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CDCLatencyTarget"
  namespace           = "AWS/DMS"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 3600 # 1 hour in seconds
  alarm_description   = "DMS replication lag exceeds 1 hour RPO target"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]

  dimensions = {
    ReplicationTaskArn = var.dms_task_arn
  }

  tags = var.tags
}

# Custom CloudWatch metrics for backup status
resource "aws_cloudwatch_log_metric_filter" "backup_success_metric" {
  name           = "hourly-backup-success-${var.environment}"
  log_group_name = "/aws/lambda/${aws_lambda_function.hourly_backup_orchestrator.function_name}"
  pattern        = "[timestamp, request_id, level=SUCCESS, message]"

  metric_transformation {
    name      = "HourlyBackupSuccess"
    namespace = "Project3/RPO"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "backup_failure_metric" {
  name           = "hourly-backup-failure-${var.environment}"
  log_group_name = "/aws/lambda/${aws_lambda_function.hourly_backup_orchestrator.function_name}"
  pattern        = "[timestamp, request_id, level=ERROR, message]"

  metric_transformation {
    name      = "HourlyBackupFailure"
    namespace = "Project3/RPO"
    value     = "1"
  }
}

# S3 Bucket for backup metadata and logs
resource "aws_s3_bucket" "backup_metadata" {
  bucket = var.backup_bucket_name

  tags = merge(var.tags, {
    Name = "backup-metadata-${var.environment}"
    Type = "rpo-enhancement"
  })
}

resource "aws_s3_bucket_versioning" "backup_metadata_versioning" {
  bucket = aws_s3_bucket.backup_metadata.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_metadata_encryption" {
  bucket = aws_s3_bucket.backup_metadata.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Dashboard for RPO monitoring
resource "aws_cloudwatch_dashboard" "rpo_monitoring" {
  dashboard_name = "rpo-monitoring-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Project3/RPO", "HourlyBackupSuccess"],
            ["Project3/RPO", "HourlyBackupFailure"],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.hourly_backup_orchestrator.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.hourly_backup_orchestrator.function_name]
          ]
          period = 3600 # 1 hour
          stat   = "Sum"
          region = var.primary_region
          title  = "Hourly Backup Performance"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = var.dms_task_arn != "" ? [
            ["AWS/DMS", "CDCLatencyTarget", "ReplicationTaskArn", var.dms_task_arn],
            ["AWS/DMS", "CDCLatencySource", "ReplicationTaskArn", var.dms_task_arn]
          ] : []
          period = 300
          stat   = "Average"
          region = var.primary_region
          title  = "DMS Replication Lag (RPO Impact)"
        }
      },
      {
        type   = "number"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Project3/RPO", "CurrentRPO"]
          ]
          period = 3600
          stat   = "Maximum"
          region = var.primary_region
          title  = "Current RPO (Minutes)"
        }
      }
    ]
  })
}
