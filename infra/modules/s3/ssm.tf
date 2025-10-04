resource "aws_ssm_parameter" "website_bucket_name" {
  name      = "/s3/website_bucket_name"
  type      = "String"
  value     = aws_s3_bucket.website.bucket
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "website_bucket_arn" {
  name      = "/s3/website_bucket_arn"
  type      = "String"
  value     = aws_s3_bucket.website.arn
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "website_bucket_domain_name" {
  name      = "/s3/website_bucket_domain_name"
  type      = "String"
  value     = aws_s3_bucket.website.bucket_domain_name
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "website_bucket_regional_domain_name" {
  name      = "/s3/website_bucket_regional_domain_name"
  type      = "String"
  value     = aws_s3_bucket.website.bucket_regional_domain_name
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "artifacts_bucket_name" {
  name      = "/s3/artifacts_bucket_name"
  type      = "String"
  value     = aws_s3_bucket.codepipeline_artifacts.bucket
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "artifacts_bucket_arn" {
  name      = "/s3/artifacts_bucket_arn"
  type      = "String"
  value     = aws_s3_bucket.codepipeline_artifacts.arn
  overwrite = true

  tags = var.tags
}
