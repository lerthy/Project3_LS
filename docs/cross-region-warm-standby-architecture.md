# Cross-Region Warm Standby Architecture

## Overview
This architecture provides high reliability and disaster recovery for your application by using a warm standby RDS instance in a secondary AWS region, kept in sync via AWS DMS. Route53 DNS failover ensures automatic traffic switch in case of primary region failure.

## Diagram

```
                +-------------------+
                |     Route 53      |
                +-------------------+
                   /           \
                  /             \
         Active (Primary)   Standby (DR)
         +----------------+  +----------------+
         | US-EAST-1      |  | US-WEST-2      |
         |  VPC           |  |  VPC           |
         |  API Gateway   |  |  API Gateway   |
         |  Lambda        |  |  Lambda        |
         |  RDS (Primary) |  |  RDS Standby   |
         +----------------+  +----------------+
                  |                ^
                  |                |
                  +------DMS-------+
```

## Key Components
- **Primary Region (US-EAST-1):**
  - VPC, API Gateway, Lambda, RDS (Primary, Multi-AZ)
- **Standby Region (US-WEST-2):**
  - VPC, API Gateway, Lambda, RDS Standby (Disaster Recovery)
- **Route 53:**
  - DNS failover between regions
- **AWS DMS:**
  - Replicates data from Primary RDS to Standby RDS

## Failover Process
1. Route53 detects failure in the primary region via health checks.
2. DNS is switched to the standby region.
3. Application connects to RDS Standby in us-west-2.
4. DMS ensures data is up-to-date for minimal RPO.

## Notes
- The standby RDS is a fully provisioned instance, not just a read replica.
- DMS can be configured for ongoing change data capture (CDC).
- Ensure your application can connect to both RDS endpoints.
