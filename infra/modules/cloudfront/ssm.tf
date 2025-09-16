# SSM Parameters for CloudFront Module Outputs
# Following naming convention: /cloudfront/<output_name>

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name  = "/cloudfront/cloudfront_distribution_id"
  type  = "String"
  value = aws_cloudfront_distribution.cdn.id

  tags = var.tags
}

resource "aws_ssm_parameter" "cloudfront_domain_name" {
  name  = "/cloudfront/cloudfront_domain_name"
  type  = "String"
  value = aws_cloudfront_distribution.cdn.domain_name

  tags = var.tags
}

resource "aws_ssm_parameter" "cloudfront_arn" {
  name  = "/cloudfront/cloudfront_arn"
  type  = "String"
  value = aws_cloudfront_distribution.cdn.arn

  tags = var.tags
}

resource "aws_ssm_parameter" "origin_access_identity_id" {
  name  = "/cloudfront/origin_access_identity_id"
  type  = "String"
  value = aws_cloudfront_origin_access_identity.website.id

  tags = var.tags
}
