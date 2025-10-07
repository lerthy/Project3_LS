output "secrets_manager_kms_key_arn" {
  description = "ARN of the KMS key used for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager_encryption.arn
}

output "secrets_manager_kms_key_alias" {
  description = "Alias of the KMS key used for Secrets Manager encryption"
  value       = aws_kms_alias.secrets_manager_encryption.name
}

output "rds_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_secret_name" {
  description = "Name of the RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.name
}
