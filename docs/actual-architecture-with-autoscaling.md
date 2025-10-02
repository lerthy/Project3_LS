# Project3 Actual Architecture Implementation (with Auto Scaling)

## Current Architecture Diagram
```
                                    [CloudFront]
                                         |
                                    [S3 Website]
                                         |
                                 [Route 53 DNS]
                                 Health Checks
                                       |
                    Active DNS         |        Failover DNS
                         +-------------)------------+
                         |                         |
            Primary Region (US-EAST-1)    Standby Region (US-WEST-2)
         +-------------------------+    +-------------------------+
         |     Default VPC        |    |     Default VPC        |
         |                        |    |                        |
         |    +--------------+    |    |    +--------------+    |
         |    | API Gateway  |    |    |    | API Gateway  |    |
         |    | (/contact)   |    |    |    | (/contact)   |    |
         |    +--------------+    |    |    +--------------+    |
         |           |           |    |           |           |
         |    +--------------+    |    |    +--------------+    |
         |    |   Lambda     |    |    |    |   Lambda     |    |
         |    | Auto Scaling |    |    |    | Auto Scaling |    |
         |    | min: 2, max: 10|    |    |    | min: 1, max: 5 |    |
         |    +--------------+    |    |    +--------------+    |
         |           |           |    |           |           |
         |    +--------------+    |    |    +--------------+    |
         |    |PostgreSQL RDS|    |    |    |PostgreSQL RDS|    |
         |    | Primary      |<---|----|--->| Standby      |    |
         |    +--------------+    |    |    +--------------+    |
         |                        |    |                        |
         |    +--------------+    |    |    +--------------+    |
         |    |     S3      |    |    |    |     S3      |    |
         |    |   Primary   |<---|----|--->|   Replica   |    |
         |    +--------------+    |    |    +--------------+    |
         +-------------------------+    +-------------------------+
                     |                              |
                     |          CloudWatch          |
                     +------- Monitoring/Logs ------+
                     |           Alarms            |
                     +----------------------------->

```

## Auto Scaling Configuration Details

### Primary Region (US-EAST-1)

1. **Lambda Auto Scaling**
   ```hcl
   Auto Scaling Configuration:
   - Minimum Capacity: 2 instances
   - Maximum Capacity: 10 instances
   - Target Utilization: 75%
   - Provisioned Concurrency: Enabled
   - Scaling Metric: LambdaProvisionedConcurrencyUtilization
   ```

2. **API Gateway**
   - Regional endpoint
   - Throttling enabled
   - WAF protection

3. **RDS Configuration**
   ```hcl
   PostgreSQL RDS:
   - Multi-AZ: Yes
   - Security Group: Inbound 5432 from Lambda
   - Enhanced Monitoring: Enabled
   ```

### Standby Region (US-WEST-2)

1. **Lambda Auto Scaling**
   ```hcl
   Standby Auto Scaling Configuration:
   - Minimum Capacity: 1 instance
   - Maximum Capacity: 5 instances
   - Scaled down for cost optimization
   - Same scaling metric as primary
   ```

2. **RDS Standby**
   ```hcl
   PostgreSQL RDS:
   - Multi-AZ: No
   - Backup Retention: 7 days
   - Storage: GP2
   ```

## CloudWatch Monitoring

### Lambda Monitoring
```hcl
CloudWatch Alarms:
- Error Rate Threshold: > 1 error
- Duration Threshold: > 10 seconds
- Concurrent Executions
```

### API Gateway Monitoring
```hcl
Metrics:
- 5XX Error Rate
- Latency (p95)
- Integration Latency
```

### RDS Monitoring
```hcl
Enhanced Monitoring:
- CPU Utilization
- Free Storage Space
- Connection Count
```

This architecture now accurately reflects your implementation including:
- Lambda auto scaling configuration
- Provisioned concurrency settings
- Monitoring thresholds
- Regional configurations
- Security group setup