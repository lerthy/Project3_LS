# S3 Cross-Region Replication for warm standby
resource "aws_s3_bucket" "website_standby" {
  provider = aws.standby
  bucket   = "project3-website-standby"
  acl      = "private"
  tags     = var.tags
}

resource "aws_s3_bucket_replication_configuration" "website_replication" {
  bucket = aws_s3_bucket.website.id
  role   = var.replication_role_arn

  rule {
    id     = "replicate-to-standby"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.website_standby.arn
      storage_class = "STANDARD"
    }
    filter {
      prefix = ""
    }
  }
}
