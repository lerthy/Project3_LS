# Provider configuration for standby region
provider "aws" {
  alias  = "standby"
  region = var.region
}

# Lambda function security group
resource "aws_security_group" "lambda" {
  name_prefix = "${var.function_name}-sg-"
  description = "Security group for Lambda function ${var.function_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.function_name}-sg"
  })
}

# Lambda function
resource "aws_lambda_function" "function" {
  provider = aws.standby
  
  function_name = var.function_name
  role         = var.lambda_role_arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"
  timeout      = 30
  memory_size  = 256
  filename     = var.lambda_zip_path

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  provider = aws.standby
  
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = var.tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "errors" {
  provider = aws.standby
  
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function error rate is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = var.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "duration" {
  provider = aws.standby
  
  alarm_name          = "${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic          = "Average"
  threshold          = 10000  # 10 seconds
  alarm_description  = "Lambda function duration is too high"
  alarm_actions      = var.alarm_actions

  dimensions = {
    FunctionName = var.function_name
  }
}