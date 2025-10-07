output "primary_health_check_id" {
  description = "ID of the primary API health check"
  value       = aws_route53_health_check.primary_api.id
}

output "standby_health_check_id" {
  description = "ID of the standby API health check"
  value       = aws_route53_health_check.standby_api.id
}

output "api_failover_record" {
  description = "Primary failover Route53 record name"
  value       = aws_route53_record.api_failover.name
}

output "api_failover_standby_record" {
  description = "Standby failover Route53 record name"
  value       = aws_route53_record.api_failover_standby.name
}
