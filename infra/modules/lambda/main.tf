# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = var.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to manage ENIs in a VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}



resource "aws_security_group" "lambda_sg" {
  name_prefix = "lambda-sg-"
  description = "Security group for Lambda to access RDS"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "lambda-sg" })
}

# IAM policy for Lambda to access SSM parameters
resource "aws_iam_role_policy" "lambda_ssm_policy" {
  name = "lambda-ssm-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/rds/rds_address",
          "arn:aws:ssm:${var.aws_region}:*:parameter/rds/db_username",
          "arn:aws:ssm:${var.aws_region}:*:parameter/rds/db_password",
          "arn:aws:ssm:${var.aws_region}:*:parameter/rds/db_name"
        ]
      }
    ]
  })
}

# Allow Lambda to read the DB secret from Secrets Manager
resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "lambda-secrets-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = var.db_secret_arn
      }
    ]
  })
}

# Lambda Function with performance optimizations
resource "aws_lambda_function" "contact" {
  filename         = "lambda-deployment.zip"
  function_name    = var.function_name
  role            = aws_iam_role.lambda_exec.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = var.timeout
  memory_size     = 128
  publish         = true
  
  # Dead Letter Queue Configuration
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  # Environment variables (using Secrets Manager for DB credentials)
  environment {
    variables = {
      DB_SECRET_ARN    = var.db_secret_arn
      DLQ_URL          = aws_sqs_queue.lambda_dlq.url
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy.lambda_secrets_policy,
  ]

  tags = var.tags
}

# Lambda Alias for versioning (required for provisioned concurrency)
resource "aws_lambda_alias" "contact_live" {
  name             = "live"
  description      = "Live version of the Lambda function"
  function_name    = aws_lambda_function.contact.function_name
  function_version = "1"

  lifecycle {
    ignore_changes = [function_version]
  }
}

# Provisioned concurrency config for Lambda
# Lambda Provisioned Concurrency disabled due to AWS account limits
# resource "aws_lambda_provisioned_concurrency_config" "contact" {
#   function_name                     = aws_lambda_function.contact.function_name
#   provisioned_concurrent_executions = 1
#   qualifier                        = aws_lambda_alias.contact_live.name
# }

# Dead-letter queue for Lambda failures
resource "aws_sqs_queue" "lambda_dlq" {
  name = "${var.function_name}-dlq"
  tags = var.tags
}

# IAM policy for Lambda to access SQS DLQ
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda-sqs-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

resource "aws_lambda_function_event_invoke_config" "contact_eic" {
  function_name = aws_lambda_function.contact.function_name
  destination_config {
    on_failure {
      destination = aws_sqs_queue.lambda_dlq.arn
    }
  }
  maximum_retry_attempts      = 2
  maximum_event_age_in_seconds = 3600
  
  depends_on = [aws_iam_role_policy.lambda_sqs_policy]
}

# Lambda permission is handled in the main configuration to avoid circular dependency

data "aws_caller_identity" "current" {}