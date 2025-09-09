resource "random_id" "rand" {
  byte_length = 4
}

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

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.contact_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.post_contact.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact.invoke_arn
}

resource "aws_api_gateway_deployment" "contact_deployment" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  depends_on  = [aws_api_gateway_integration.lambda_integration]
}

resource "aws_api_gateway_stage" "contact_stage" {
  deployment_id = aws_api_gateway_deployment.contact_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  stage_name    = "dev"
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
  source_code_hash = fileexists("lambda.zip") ? filebase64sha256("lambda.zip") : null

  environment {
    variables = {
      DB_HOST = aws_db_instance.contact_db.address
      DB_USER = data.aws_ssm_parameter.db_username.value
      DB_PASS = data.aws_ssm_parameter.db_password.value
      DB_NAME = var.db_name
    }
  }
}

# -------------------
# RDS Database
# -------------------
data "aws_ssm_parameter" "db_username" {
  name = "/contact/db_username"
}

data "aws_ssm_parameter" "db_password" {
  name            = "/contact/db_password"
  with_decryption = true
}

resource "aws_db_instance" "contact_db" {
  identifier        = "contact-db"
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
  publicly_accessible   = false  # Security best practice
  deletion_protection   = false  # Allow deletion for cleanup
  
  # Database configuration
  username = var.db_username
  password = data.aws_ssm_parameter.db_password.value
  db_name  = var.db_name

  # Important: Skip final snapshot to avoid charges
  skip_final_snapshot = true
  delete_automated_backups = true  # Clean up backups on deletion
  
  tags = {
    Name = "contact-db-free-tier"
    Environment = "development"
    Project = "assignment"
  }
}
