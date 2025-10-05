# S3 Bucket for Website
resource "aws_s3_bucket" "website" {
  bucket        = var.website_bucket_name
  force_destroy = true

  tags = var.tags
}

# Enable bucket versioning for website bucket
resource "aws_s3_bucket_versioning" "website_versioning" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption for website bucket with AES256 (simpler for CloudFront access)
resource "aws_s3_bucket_server_side_encryption_configuration" "website_encryption" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

# S3 bucket static website configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Block public access - use CloudFront OAI instead
resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "website_cloudfront_read" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CloudFrontReadGetObject",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${var.cloudfront_oai_id}"
        },
        Action = ["s3:GetObject"],
        Resource = [
          "${aws_s3_bucket.website.arn}/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.website_public_access]
}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = var.artifacts_bucket_name
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption for artifacts bucket with customer-managed KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts_encryption" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_codepipeline_encryption.arn
    }
    bucket_key_enabled = true # Cost optimization for KMS
  }
}

# S3 Intelligent-Tiering configuration for automatic cost optimization
resource "aws_s3_bucket_intelligent_tiering_configuration" "website_tiering" {
  bucket = aws_s3_bucket.website.id
  name   = "website-intelligent-tiering"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "website_lifecycle" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"
    filter {
      prefix = ""
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition_to_ia"
    status = "Enabled"
    filter {
      prefix = ""
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# Add lifecycle for artifacts bucket too
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_lifecycle" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    id     = "cleanup_artifacts"
    status = "Enabled"
    filter {
      prefix = ""
    }
    noncurrent_version_expiration {
      noncurrent_days = 7 # Shorter retention for CI/CD artifacts
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    expiration {
      days = 90 # Delete old artifacts after 90 days
    }
  }
}

# Upload website files to S3 bucket
locals {
  web_root = "${path.root}/../web/static"

  website_files = {
    "index.html"   = "${local.web_root}/index.html"
    "contact.html" = "${local.web_root}/contact.html"
    "style.css"    = "${local.web_root}/style.css"
  }

  js_files = {
    "js/config.js"  = "${local.web_root}/js/config.js"
    "js/contact.js" = "${local.web_root}/js/contact.js"
  }

  # Get all asset files dynamically
  asset_files = {
    for file in fileset("${local.web_root}/assets", "**") :
    "assets/${file}" => "${local.web_root}/assets/${file}"
  }
}

# Helper function to determine MIME type
locals {
  mime_types = {
    ".html"  = "text/html"
    ".css"   = "text/css"
    ".js"    = "application/javascript"
    ".ttf"   = "font/ttf"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".eot"   = "application/vnd.ms-fontobject"
    ".svg"   = "image/svg+xml"
  }
}

resource "aws_s3_object" "website_files" {
  for_each = local.website_files

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  source       = each.value
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.key), "application/octet-stream")
  etag         = filemd5(each.value)
}

# Generate dynamic config.js with API Gateway configuration
resource "aws_s3_object" "config_js" {
  bucket       = aws_s3_bucket.website.id
  key          = "js/config.js"
  content_type = "application/javascript"

  content = templatefile("${path.module}/templates/config.js.tpl", {
    api_gateway_url = var.api_gateway_url
    api_key         = var.api_key
  })

  etag = md5(templatefile("${path.module}/templates/config.js.tpl", {
    api_gateway_url = var.api_gateway_url
    api_key         = var.api_key
  }))
}

# Upload other JS files (excluding config.js as it's generated)
resource "aws_s3_object" "js_files" {
  for_each = {
    for k, v in local.js_files : k => v if k != "js/config.js"
  }

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  source       = each.value
  content_type = "application/javascript"
  etag         = filemd5(each.value)
}

resource "aws_s3_object" "asset_files" {
  for_each = local.asset_files

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  source       = each.value
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.key), "application/octet-stream")
  etag         = filemd5(each.value)
}
