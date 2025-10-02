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
