output "website_bucket_name" {
  description = "Name of the website S3 bucket"
  value       = aws_s3_bucket.website.bucket
}

output "website_bucket_arn" {
  description = "ARN of the website S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "website_bucket_domain_name" {
  description = "Domain name of the website S3 bucket"
  value       = aws_s3_bucket.website.bucket_domain_name
}

output "website_bucket_regional_domain_name" {
  description = "Regional domain name of the website S3 bucket"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "artifacts_bucket_name" {
  description = "Name of the CodePipeline artifacts S3 bucket"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "codepipeline_artifacts_bucket_arn" {
  description = "ARN of the CodePipeline artifacts bucket"
  value       = aws_s3_bucket.codepipeline_artifacts.arn
}

# KMS Key Outputs
output "website_kms_key_arn" {
  description = "ARN of the KMS key used for website bucket encryption"
  value       = aws_kms_key.s3_website_encryption.arn
}

output "website_kms_key_alias" {
  description = "Alias of the KMS key used for website bucket encryption"
  value       = aws_kms_alias.s3_website_encryption.name
}

output "artifacts_kms_key_arn" {
  description = "ARN of the KMS key used for artifacts bucket encryption"
  value       = aws_kms_key.s3_artifacts_encryption.arn
}

output "artifacts_kms_key_alias" {
  description = "Alias of the KMS key used for artifacts bucket encryption"
  value       = aws_kms_alias.s3_artifacts_encryption.name
}
