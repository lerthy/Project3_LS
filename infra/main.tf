resource "random_id" "rand" {
  byte_length = 4
}

# SSM parameters for DB credentials (read-only)
data "aws_ssm_parameter" "db_username" {
  name = var.db_username_ssm_name
}

data "aws_ssm_parameter" "db_password" {
  name = var.db_password_ssm_name
  with_decryption = true
}

data "aws_ssm_parameter" "db_name" {
  name = var.db_name_ssm_name
}

data "aws_ssm_parameter" "github_token" {
  name = "/project3/github/token"
  with_decryption = true
}

# Security note: Secrets (DB creds, S3 bucket name, etc.) must be stored in AWS Secrets Manager or SSM Parameter Store, not hardcoded.
# -------------------
# S3 Bucket for Website
# -------------------
resource "aws_s3_bucket" "website" {
  bucket        = "my-website-bucket-${random_id.rand.hex}"
  force_destroy = true
}

# S3 bucket static website configuration (replaces deprecated 'website' block)
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Allow public website access for static hosting
resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_public_read" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = [
          "${aws_s3_bucket.website.arn}/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.website_public_access]
}

# -------------------
# CloudFront Distribution
# -------------------
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "s3-website-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-website-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# -------------------
# API Gateway
# -------------------
resource "aws_api_gateway_rest_api" "contact_api" {
  name        = "contact-api"
  description = "API for contact form submissions"
}

resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  parent_id   = aws_api_gateway_rest_api.contact_api.root_resource_id
  path_part   = "contact"
}

resource "aws_api_gateway_method" "post_contact" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# GET method was temporary for verification; removed for security

# Add OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "options_contact" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.contact_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.post_contact.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact.invoke_arn
}

# Removed GET integration

# Integrate OPTIONS to Lambda as well (Lambda returns CORS headers)
resource "aws_api_gateway_integration" "lambda_integration_options" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.options_contact.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.options_contact.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.options_contact.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Origin'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "contact_deployment" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  depends_on  = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.lambda_integration_options,
    aws_api_gateway_method_response.options_200,
    aws_api_gateway_integration_response.options_200
  ]

  # Force a new deployment when integrations/methods change
  triggers = {
    redeploy = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "contact_stage" {
  deployment_id = aws_api_gateway_deployment.contact_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  stage_name    = "dev"
}

# Ensure CORS headers are present on API Gateway default error responses (4XX/5XX)
resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Origin'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Origin'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
  }
}

# -------------------
# IAM Role for Lambda
# -------------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -------------------
# Lambda Function
# -------------------
resource "aws_lambda_function" "contact" {
  filename         = "lambda.zip"
  function_name    = "contact-form"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 10
  source_code_hash = fileexists("lambda.zip") ? filebase64sha256("lambda.zip") : null

  environment {
    variables = {
      DB_HOST = aws_db_instance.contact_db.address
      DB_USER = coalesce(var.db_username, data.aws_ssm_parameter.db_username.value)
      DB_PASS = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)
      DB_NAME = coalesce(var.db_name, data.aws_ssm_parameter.db_name.value)
    }
  }
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.contact_api.id}/*/*/contact"
}

data "aws_caller_identity" "current" {}

# -------------------
# RDS Database
# -------------------
resource "aws_db_instance" "contact_db" {
  identifier        = "contact-db-${random_id.rand.hex}"
  engine            = "postgres"
  engine_version    = "15.7"  # Specific version for predictability
  instance_class    = "db.t3.micro"  # Free Tier eligible
  allocated_storage = 20  # Free Tier: 20GB included
  max_allocated_storage = 20  # Prevent auto-scaling beyond Free Tier
  
  # Free Tier optimizations
  storage_type          = "gp2"  # General Purpose SSD (Free Tier eligible)
  backup_retention_period = 7   # Free Tier: 7 days included, but let's use minimal
  backup_window         = "03:00-04:00"  # Non-peak hours
  maintenance_window    = "sun:04:00-sun:05:00"  # Non-peak hours
  
  # Security but Free Tier friendly
  storage_encrypted     = false  # Encryption might have costs in some scenarios
  publicly_accessible   = true   # For demo connectivity from Lambda (no VPC)
  deletion_protection   = false  # Allow deletion for cleanup
  
  # Database configuration
  username = coalesce(var.db_username, data.aws_ssm_parameter.db_username.value)
  password = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)
  db_name  = coalesce(var.db_name, data.aws_ssm_parameter.db_name.value)

  vpc_security_group_ids = [aws_security_group.rds_public.id]

  # Important: Skip final snapshot to avoid charges
  skip_final_snapshot = true
  delete_automated_backups = true  # Clean up backups on deletion
  
  tags = {
    Name = "contact-db-free-tier"
    Environment = "development"
    Project = "assignment"
  }
}

# Default VPC to host RDS security group
data "aws_vpc" "default" {
  default = true
}

# Public inbound for PostgreSQL (demo only)
resource "aws_security_group" "rds_public" {
  name_prefix = "rds-public-ingress-5432-"
  description = "Allow public inbound to Postgres (demo)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # Demo-only: allow public access so Lambda (not in VPC) can reach RDS
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# -------------------
# S3 Bucket for CodePipeline Artifacts
# -------------------
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "codepipeline-artifacts-${random_id.rand.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# -------------------
# IAM Role for CodePipeline
# -------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-${random_id.rand.hex}"

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
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      }
    ]
  })
}

# -------------------
# Infrastructure Pipeline (Terraform)
# -------------------
resource "aws_codepipeline" "infra_pipeline" {
  name     = "project3-infra-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "lerthy"
        Repo       = "Project3_LS"
        Branch     = "develop"
        OAuthToken = data.aws_ssm_parameter.github_token.value
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.infra_project.name
      }
    }
  }
}

# -------------------
# Web Application Pipeline
# -------------------
resource "aws_codepipeline" "web_pipeline" {
  name     = "project3-web-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "lerthy"
        Repo       = "Project3_LS"
        Branch     = "develop"
        OAuthToken = data.aws_ssm_parameter.github_token.value
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web_project.name
      }
    }
  }
}
