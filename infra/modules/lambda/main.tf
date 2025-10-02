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
  memory_size = 256
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = var.runtime
  timeout          = var.timeout
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : null
  reserved_concurrent_executions = 5
  
  # Customer-managed KMS encryption for environment variables
  kms_key_arn = aws_kms_key.lambda_env_encryption.arn
  
  vpc_config {
    subnet_ids         = data.aws_subnets.default_vpc_subnets.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      NODE_OPTIONS = "--enable-source-maps"
      POSTGRES_MAX_CONNECTIONS = "10"
      ENVIRONMENT = "development"
      DB_SECRET_ARN = var.db_secret_arn
    }
  }
  tags = var.tags
}

# Provisioned concurrency config for Lambda
resource "aws_lambda_provisioned_concurrency_config" "contact" {
  function_name                     = aws_lambda_function.contact.function_name
  provisioned_concurrent_executions = 2
  qualifier                        = aws_lambda_function.contact.version
}

# Dead-letter queue for Lambda failures
resource "aws_sqs_queue" "lambda_dlq" {
  name = "contact-form-dlq"
  tags = var.tags
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
}

# Lambda permission is handled in the main configuration to avoid circular dependency

data "aws_caller_identity" "current" {}