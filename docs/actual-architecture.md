# Project3 VPC and Network Architecture (Actual Implementation)

## Current Architecture Diagram
```
                                    AWS Cloud
                                 [Route 53 DNS]
                                 Health Checks
                                       |
                    Active DNS         |        Failover DNS
                         +-------------)------------+
                         |                         |
            Primary Region (US-EAST-1)    Standby Region (US-WEST-2)
         +-------------------------+    +-------------------------+
         |        VPC             |    |         VPC            |
         |  +------------------+  |    |  +------------------+  |
         |  |    +--------+    |  |    |  |    +--------+    |  |
         |  |    |  API   |    |  |    |  |    |  API   |    |  |
         |  |    |Gateway |    |  |    |  |    |Gateway |    |  |
         |  |    +--------+    |  |    |  |    +--------+    |  |
         |  |         |        |  |    |  |         |        |  |
         |  |    +--------+    |  |    |  |    +--------+    |  |
         |  |    | Lambda |    |  |    |  |    | Lambda |    |  |
         |  |    |Function|    |  |    |  |    |Function|    |  |
         |  |    +--------+    |  |    |  |    +--------+    |  |
         |  |         |        |  |    |  |         |        |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  |    |Postgres |   |  |    |  |    |Postgres |   |  |
         |  |    |  RDS    |<--|--|----|----|----| RDS    |   |  |
         |  |    | Primary |   |  |    |  |    |Standby  |   |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  |         |        |  |    |  |         |        |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  |    |   S3    |   |  |    |  |    |   S3    |   |  |
         |  |    | Website |<--|--|----|----|----| Replica|   |  |
         |  |    | Bucket  |   |  |    |  |    | Bucket |   |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  +------------------+  |    |  +------------------+  |
         +-------------------------+    +-------------------------+
                      |                              |
                      |         CloudWatch           |
                      +--------- Monitoring ---------+
                      |          Alarms             |
                      +----------------------------->

```

## Actual Component Details (From Your Infrastructure)

### Primary Region (US-EAST-1)

1. **VPC Configuration**
   ```hcl
   # From your actual configuration
   data "aws_vpc" "default" {
     default = true
   }
   ```

2. **RDS Configuration**
   ```hcl
   # From your infra/modules/rds/main.tf
   Security Group:
   - Inbound: Port 5432 from Lambda
   - Engine: PostgreSQL
   - Enhanced Monitoring: Enabled
   - Multi-AZ: Yes
   ```

3. **Lambda & API Gateway**
   - Single API Gateway endpoint for contact form
   - One Lambda function for form processing
   - Security group access to RDS

4. **S3 Configuration**
   - Static website hosting bucket
   - Cross-region replication to standby region

### Standby Region (US-WEST-2)

1. **VPC Configuration**
   ```hcl
   # From your infra/modules/rds-standby/main.tf
   data "aws_vpc" "standby" {
     provider = aws.standby
     default  = true
   }
   ```

2. **RDS Standby Configuration**
   ```hcl
   # From your actual standby configuration
   - Engine: PostgreSQL
   - Multi-AZ: No (cost optimization)
   - Backup Retention: 7 days
   - Storage: GP2
   - Publicly Accessible: No
   ```

3. **Route 53 Failover**
   ```hcl
   # From your route53/failover.tf
   - Health check on /contact endpoint
   - 30-second intervals
   - 3 failure threshold
   - Failover routing policy
   ```

## Network Security Implementation

### Security Groups
```hcl
# From your actual configuration
RDS Security Group:
- Inbound Rule:
  - Port: 5432
  - Source: Lambda Security Group
  - Protocol: TCP

- Outbound Rule:
  - All Traffic
  - Destination: 0.0.0.0/0
```

## Failover Process

1. **Normal Operation**
   ```
   User → Route 53 → Primary API Gateway → Lambda → RDS Primary
   ```

2. **During Failover**
   ```
   User → Route 53 → Standby API Gateway → Lambda → RDS Standby
   ```

## Monitoring Setup

### CloudWatch Configuration
- RDS performance metrics
- API Gateway metrics
- Lambda execution metrics
- Route 53 health check status

This architecture diagram and documentation now accurately reflects your actual project components and configuration, specifically:
- PostgreSQL RDS instead of Aurora
- Your actual security group configurations
- Your specific Route 53 setup
- Your actual VPC configuration using default VPCs
- The exact monitoring and failover setup from your code