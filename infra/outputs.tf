output "bucket_name" {
  description = "S3 bucket name hosting the website"
  value       = aws_s3_bucket.website.bucket
}

output "cloudfront_url" {
  description = "CloudFront distribution domain name for the website"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for cache invalidations"
  value       = aws_cloudfront_distribution.cdn.id
}

output "api_gateway_url" {
  description = "Invoke URL for the contact form API"
  value       = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.aws_region}.amazonaws.com/dev/contact"
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint address"
  value       = aws_db_instance.contact_db.address
}
