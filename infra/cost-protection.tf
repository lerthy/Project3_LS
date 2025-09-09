# Free Tier Monitoring

# cloudWatch billing alarm
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "billing-alarm-5-usd"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # 24hr
  statistic           = "Maximum"
  threshold           = "5"  # Alert if charges exceed 5 dollars
  alarm_description   = "This metric monitors AWS estimated charges"
  alarm_actions       = []

  dimensions = {
    Currency = "USD"
  }

  tags = {
    Environment = "development"
    Purpose = "cost-protection"
  }
}

# S3 lifecycle rule to prevent storage accumulation
resource "aws_s3_bucket_lifecycle_configuration" "website_lifecycle" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"
    
    filter {
      prefix = ""  # Apply to all objects
    }

    noncurrent_version_expiration {
      noncurrent_days = 7  # Delete old versions after 7 days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1  # Clean up failed uploads
    }
  }
}
