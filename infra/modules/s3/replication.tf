# S3 Cross-Region Replication for warm standby (conditional)
resource "aws_s3_bucket" "website_standby" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.standby
  bucket   = "project3-website-standby"
  tags     = var.tags
}

resource "aws_s3_bucket_acl" "website_standby_acl" {
  count      = var.enable_replication ? 1 : 0
  provider   = aws.standby
  bucket     = aws_s3_bucket.website_standby[0].id
  acl        = "private"
  depends_on = [aws_s3_bucket.website_standby]
}

resource "aws_s3_bucket_replication_configuration" "website_replication" {
  count  = var.enable_replication ? 1 : 0
  bucket = aws_s3_bucket.website.id
  role   = var.replication_role_arn

  rule {
    id     = "replicate-to-standby"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.website_standby[0].arn
      storage_class = "STANDARD_IA" # Use IA for cost savings on standby region
    }
    filter {
      prefix = ""
    }
  }
}

# CloudFront OAI access policy for standby bucket
resource "aws_s3_bucket_policy" "website_standby_policy" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.standby
  bucket   = aws_s3_bucket.website_standby[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontOAIAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${var.cloudfront_oai_id}"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_standby[0].arn}/*"
      }
    ]
  })
}

# Block public access for standby bucket
resource "aws_s3_bucket_public_access_block" "website_standby_public_access" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.standby
  bucket   = aws_s3_bucket.website_standby[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for standby bucket (required for replication)
resource "aws_s3_bucket_versioning" "website_standby_versioning" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.standby
  bucket   = aws_s3_bucket.website_standby[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}
