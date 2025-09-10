output "bucket_name" {
  value = aws_s3_bucket.website.bucket
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.aws_region}.amazonaws.com/dev/contact"
}

output "rds_endpoint" {
  value = aws_db_instance.contact_db.address
}
