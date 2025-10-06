output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.rds_replication.replication_instance_arn
}

output "replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.rds_replication.replication_instance_id
}

output "source_endpoint_arn" {
  description = "ARN of the DMS source endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "target_endpoint_arn" {
  description = "ARN of the DMS target endpoint"
  value       = aws_dms_endpoint.target.endpoint_arn
}

output "replication_task_arn" {
  description = "ARN of the DMS replication task"
  value       = aws_dms_replication_task.rds_to_standby.replication_task_arn
}

output "replication_task_id" {
  description = "ID of the DMS replication task"
  value       = aws_dms_replication_task.rds_to_standby.replication_task_id
}
