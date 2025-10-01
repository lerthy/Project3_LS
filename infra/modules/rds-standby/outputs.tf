output "standby_db_endpoint" {
  description = "Endpoint of the standby RDS instance"
  value       = aws_db_instance.contact_db_standby.endpoint
}

output "standby_db_arn" {
  description = "ARN of the standby RDS instance"
  value       = aws_db_instance.contact_db_standby.arn
}

output "standby_db_sg_id" {
  description = "Security group ID for standby RDS"
  value       = aws_security_group.rds_ingress_standby.id
}
