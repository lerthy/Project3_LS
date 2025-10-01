# Warm Standby Architecture for Project3

## Overview
This project now supports a warm standby setup in a different AWS region for improved reliability and disaster recovery.

## Components
- **Standby RDS**: Deployed in `us-west-2` (see `infra/modules/rds-standby/main.tf`).
- **S3 Cross-Region Replication**: Website bucket replicates to standby region (see `infra/modules/s3/replication.tf`).
- **Route53 DNS Failover**: Automated failover between primary and standby APIs (see `infra/modules/route53/failover.tf`).

## Failover Process
1. Route53 health checks monitor both primary and standby APIs.
2. If the primary API fails, Route53 automatically routes traffic to the standby API.
3. Standby RDS and S3 buckets are ready to scale up and serve production traffic.

## Testing & Validation
- Regularly test failover by simulating outages.
- Monitor CloudWatch alarms and Route53 health checks.
- Ensure data replication is working (S3, RDS backups/read replicas).

## Notes
- Standby resources are scaled down for cost efficiency but can be scaled up quickly.
- Update secrets and environment variables for standby region as needed.
- Review and adjust IAM roles for cross-region access.
