# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "OAI for website bucket"
}

# S3 bucket for CloudFront access logs
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket        = "${var.s3_bucket_name}-cf-logs"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs_lifecycle" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  
  rule {
    id     = "delete_old_logs"
    status = "Enabled"
    filter {
      prefix = "cloudfront-logs/"
    }
    expiration {
      days = var.log_retention_days
    }
  }
}

# Performance-optimized response headers policy
resource "aws_cloudfront_response_headers_policy" "optimized" {
  name = "performance-optimized-policy"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000"
      override = true
    }
    items {
      header   = "Accept-Encoding"
      value    = "gzip, deflate, br"
      override = true
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains = true
      override = true
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = var.s3_bucket_regional_domain_name
    origin_id   = "s3-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled    = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-origin"
    compress        = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
    }

    viewer_protocol_policy     = "redirect-to-https"
    min_ttl                    = 0
    default_ttl                = 86400    # 24 hours
    max_ttl                    = 31536000 # 1 year
    response_headers_policy_id = aws_cloudfront_response_headers_policy.optimized.id
  }

  # Specific cache behavior for static assets
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"
    compress        = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl               = 86400    # 1 day
    default_ttl           = 604800   # 1 week
    max_ttl               = 31536000 # 1 year
    response_headers_policy_id = aws_cloudfront_response_headers_policy.optimized.id
  }

  # Cost optimization: Use price class that covers US, Canada, Europe, and Asia
  price_class = var.price_class

  # Enable access logging for cost analysis
  logging_config {
    include_cookies = false
    bucket         = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix         = "cloudfront-logs/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = var.tags
}
