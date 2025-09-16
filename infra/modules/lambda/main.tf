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

# Lambda Function
resource "aws_lambda_function" "contact" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = var.runtime
  timeout          = var.timeout
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : null

  environment {
    variables = {
      AWS_REGION = var.aws_region
      # Database credentials now retrieved from SSM parameters in the function
      # No longer passing sensitive data as environment variables
    }
  }

  tags = var.tags
}

# Lambda permission is handled in the main configuration to avoid circular dependency

resource "random_id" "rand" {
  byte_length = 4
}

data "aws_caller_identity" "current" {}
