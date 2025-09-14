# S3 Bucket for Website
resource "aws_s3_bucket" "website" {
  bucket        = var.website_bucket_name
  force_destroy = true

  tags = var.tags
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
        Sid       = "CloudFrontReadGetObject",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${var.cloudfront_oai_id}"
        },
        Action    = ["s3:GetObject"],
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

# S3 lifecycle rule to prevent storage accumulation
# TEMPORARILY REMOVED - Will be re-added after IAM permissions are fixed
# resource "aws_s3_bucket_lifecycle_configuration" "website_lifecycle" {
#   bucket = aws_s3_bucket.website.id
#
#   rule {
#     id     = "cleanup_old_versions"
#     status = "Enabled"
#
#     filter {
#       prefix = "" # Apply to all objects
#     }
#
#     noncurrent_version_expiration {
#       noncurrent_days = 7 # Delete old versions after 7 days
#     }
#
#     abort_incomplete_multipart_upload {
#       days_after_initiation = 1 # Clean up failed uploads
#     }
#   }
# }
