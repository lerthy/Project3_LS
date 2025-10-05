output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.contact_db.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.contact_db.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.contact_db.port
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.contact_db.arn
}

output "security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds_ingress.id
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.contact_db.identifier
}

# Secrets Management Outputs
output "kms_key_arn" {
  description = "ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds_encryption.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for RDS encryption"
  value       = aws_kms_alias.rds_encryption.name
}

output "rds_security_group_id" {
  description = "Security group ID for RDS access"
  value       = aws_security_group.rds_ingress.id
}

output "dms_task_id" {
  description = "DMS replication task identifier"
  value       = var.environment == "production" && length(aws_dms_replication_task.rds_to_standby) > 0 ? aws_dms_replication_task.rds_to_standby[0].replication_task_id : ""
}

output "dms_task_arn" {
  description = "DMS replication task ARN"
  value       = var.environment == "production" && length(aws_dms_replication_task.rds_to_standby) > 0 ? aws_dms_replication_task.rds_to_standby[0].replication_task_arn : ""
}
