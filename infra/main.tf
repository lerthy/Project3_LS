resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "website" {
  bucket        = "my-website-bucket-${random_id.rand.hex}"
  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "s3-origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
