# Project3 Actual Architecture Implementation

## High-Level Architecture
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
         |    | (Node.js 18) |    |    |    | (Node.js 18) |    |
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

## Actual Implementation Details

### Static Website Hosting
- **CloudFront Distribution**
  - Origin: S3 bucket
  - TLS: TLSv1.2_2021
  - Cache behaviors:
    - Default: `index.html`
    - `/assets/*`: 1 year cache
  - Geographic restrictions: None

### Primary Region (US-EAST-1)

1. **API Gateway**
   - Type: REST API
   - Endpoint: `/contact`
   - Methods: POST
   - Integration: Lambda

2. **Lambda Function**
   - Runtime: Node.js 18
   - Handler: `index.js`
   - Environment: Production
   - Security Group: Outbound to RDS

3. **RDS Primary**
   - Engine: PostgreSQL
   - Security Group: 
     - Inbound: Port 5432 from Lambda SG
   - Multi-AZ: Yes
   - Monitoring: Enhanced

4. **S3 Primary**
   - Website hosting enabled
   - Cross-region replication
   - Public access blocked
   - Versioning enabled

### Standby Region (US-WEST-2)

1. **API Gateway**
   - Same configuration as primary
   - Scaled down for cost

2. **Lambda Function**
   - Identical code as primary
   - Minimal capacity configuration

3. **RDS Standby**
   - Engine: PostgreSQL
   - Multi-AZ: No
   - Backup Retention: 7 days
   - Storage: GP2
   - Public Access: No

4. **S3 Replica**
   - Replication target from primary
   - Same security configuration

### Route 53 Failover Configuration
```hcl
Health Checks:
- Endpoint: /contact
- Protocol: HTTPS
- Port: 443
- Interval: 30s
- Failure Threshold: 3
```

### Monitoring Setup
1. **CloudWatch**
   - Lambda execution logs
   - API Gateway metrics
   - RDS performance metrics
   - Billing alarm ($5 threshold)

2. **Health Checks**
   - API endpoint monitoring
   - Database connectivity
   - Replication lag

### Security Implementation

1. **VPC Security**
   ```hcl
   Primary & Standby:
   - Default VPC
   - Security Groups for RDS access
   ```

2. **Database Security**
   ```hcl
   - Port: 5432
   - Inbound: Lambda SG only
   - Encryption: At rest
   - Public access: Disabled
   ```

3. **API Security**
   - HTTPS only
   - API Gateway authorization
   - Lambda execution role

### CI/CD Integration
- Two CodePipelines:
  1. Infrastructure Pipeline (Terraform)
  2. Web Application Pipeline
- CodeBuild for build/test
- S3 artifacts bucket
- CloudFront invalidation

This architecture accurately reflects your current implementation with:
- Default VPC usage
- Actual security group configurations
- Real monitoring setup
- Existing CI/CD pipeline structure
- Current failover configuration