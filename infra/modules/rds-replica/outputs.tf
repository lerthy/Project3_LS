output "replica_instance_id" {
  description = "The identifier of the RDS replica instance"
  value       = aws_db_instance.replica.id
}

output "replica_endpoint" {
  description = "The connection endpoint for the RDS replica"
  value       = aws_db_instance.replica.endpoint
}

output "replica_arn" {
  description = "The ARN of the RDS replica"
  value       = aws_db_instance.replica.arn
}

output "security_group_id" {
  description = "The ID of the security group created for the RDS replica"
  value       = aws_security_group.rds_replica.id
}

output "replica_port" {
  description = "The port on which the RDS replica accepts connections"
  value       = aws_db_instance.replica.port
}

output "cloudwatch_dashboard_name" {
  description = "The name of the CloudWatch dashboard created for monitoring"
  value       = aws_cloudwatch_dashboard.replica.dashboard_name
}

output "replica_status" {
  description = "The current status of the replica"
  value       = aws_db_instance.replica.status
}

output "replica_availability_zone" {
  description = "The AZ where the replica instance is deployed"
  value       = aws_db_instance.replica.availability_zone
}