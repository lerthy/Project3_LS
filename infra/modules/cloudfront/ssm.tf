resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name      = "/cloudfront/cloudfront_distribution_id"
  type      = "String"
  value     = aws_cloudfront_distribution.cdn.id
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "cloudfront_domain_name" {
  name      = "/cloudfront/cloudfront_domain_name"
  type      = "String"
  value     = aws_cloudfront_distribution.cdn.domain_name
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "cloudfront_arn" {
  name      = "/cloudfront/cloudfront_arn"
  type      = "String"
  value     = aws_cloudfront_distribution.cdn.arn
  overwrite = true

  tags = var.tags
}

resource "aws_ssm_parameter" "origin_access_identity_id" {
  name      = "/cloudfront/origin_access_identity_id"
  type      = "String"
  value     = aws_cloudfront_origin_access_identity.website.id
  overwrite = true

  tags = var.tags
}
