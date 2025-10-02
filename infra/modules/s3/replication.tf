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
      storage_class = "STANDARD_IA"  # Use IA for cost savings on standby region
    }
    filter {
      prefix = ""
    }
  }
}
