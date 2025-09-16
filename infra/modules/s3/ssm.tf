# SSM Parameters for S3 Module Outputs
# Following naming convention: /s3/<output_name>

resource "aws_ssm_parameter" "website_bucket_name" {
  name  = "/s3/website_bucket_name"
  type  = "String"
  value = aws_s3_bucket.website.bucket

  tags = var.tags
}

resource "aws_ssm_parameter" "website_bucket_arn" {
  name  = "/s3/website_bucket_arn"
  type  = "String"
  value = aws_s3_bucket.website.arn

  tags = var.tags
}

resource "aws_ssm_parameter" "website_bucket_domain_name" {
  name  = "/s3/website_bucket_domain_name"
  type  = "String"
  value = aws_s3_bucket.website.bucket_domain_name

  tags = var.tags
}

resource "aws_ssm_parameter" "website_bucket_regional_domain_name" {
  name  = "/s3/website_bucket_regional_domain_name"
  type  = "String"
  value = aws_s3_bucket.website.bucket_regional_domain_name

  tags = var.tags
}

resource "aws_ssm_parameter" "artifacts_bucket_name" {
  name  = "/s3/artifacts_bucket_name"
  type  = "String"
  value = aws_s3_bucket.codepipeline_artifacts.bucket

  tags = var.tags
}

resource "aws_ssm_parameter" "artifacts_bucket_arn" {
  name  = "/s3/artifacts_bucket_arn"
  type  = "String"
  value = aws_s3_bucket.codepipeline_artifacts.arn

  tags = var.tags
}
