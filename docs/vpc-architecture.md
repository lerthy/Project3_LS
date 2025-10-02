# VPC and Network Architecture Implementation

## Detailed Architecture Diagram
```
                                    AWS Cloud
                                 [Route 53 DNS]
                                       |
                    Active DNS         |        Failover DNS
                         +-------------)------------+
                         |                         |
            Primary Region (US-EAST-1)    Standby Region (US-WEST-2)
         +-------------------------+    +-------------------------+
         |        VPC             |    |         VPC            |
         |  +------------------+  |    |  +------------------+  |
         |  | Availability Zone|  |    |  | Availability Zone|  |
         |  |    +--------+    |  |    |  |    +--------+    |  |
         |  |    |  API   |    |  |    |  |    |  API   |    |  |
         |  |    |Gateway |    |  |    |  |    |Gateway |    |  |
         |  |    +--------+    |  |    |  |    +--------+    |  |
         |  |         |        |  |    |  |         |        |  |
         |  | +---------------+|  |    |  | +---------------+|  |
         |  | |Auto Scaling   ||  |    |  | |Auto Scaling   ||  |
         |  | |Group          ||  |    |  | |Group          ||  |
         |  | |  +--------+   ||  |    |  | |  +--------+   ||  |
         |  | |  |Lambda  |   ||  |    |  | |  |Lambda  |   ||  |
         |  | |  |Function|   ||  |    |  | |  |Function|   ||  |
         |  | |  +--------+   ||  |    |  | |  +--------+   ||  |
         |  | +---------------+|  |    |  | +---------------+|  |
         |  |         |        |  |    |  |         |        |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  |    | Aurora  |   |  |    |  |    | Aurora  |   |  |
         |  |    | Primary |<--|--|----|----|----| Replica|   |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  |         |        |  |    |  |         |        |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  |    |   S3    |   |  |    |  |    |   S3    |   |  |
         |  |    | Primary |<--|--|----|----|----| Replica|   |  |
         |  |    +---------+   |  |    |  |    +---------+   |  |
         |  +------------------+  |    |  +------------------+  |
         +-------------------------+    +-------------------------+
                      |                              |
                      |         CloudWatch           |
                      +--------- Monitoring ---------+
                      |          Alarms             |
                      +----------------------------->

```

## Network Connections and Data Flow

### Primary Region (US-EAST-1)

1. **VPC Configuration**
   - Default VPC used (as per your configuration)
   - Security groups configured for internal communication
   - Private subnets for RDS and Lambda
   - Public subnets for API Gateway

2. **Network Flow**
   ```
   Internet → Route 53 → API Gateway → Lambda → Aurora Primary
                                              ↓
                                         S3 Primary
   ```

3. **Security Group Configuration**
   ```hcl
   RDS Security Group:
   - Inbound: Port 5432 from Lambda SG
   - Outbound: All traffic allowed
   
   Lambda Security Group:
   - Outbound: Port 5432 to RDS SG
   - Outbound: HTTPS to internet (443)
   ```

### Standby Region (US-WEST-2)

1. **VPC Configuration**
   - Mirror of primary region VPC
   - Scaled-down but identical security configuration
   - Same subnet structure as primary

2. **Network Flow**
   ```
   (During Failover)
   Internet → Route 53 → API Gateway → Lambda → Aurora Replica
                                              ↓
                                         S3 Replica
   ```

### Cross-Region Connections

1. **Database Replication**
   ```
   Aurora Primary -----> Aurora Replica
   (Asynchronous Cross-Region Replication)
   ```

2. **S3 Replication**
   ```
   S3 Primary -----> S3 Replica
   (Cross-Region Replication)
   ```

3. **Route 53 Health Checks**
   ```
   Route 53 ---> Primary Endpoint (Active)
           ---> Standby Endpoint (Passive)
   ```

## Component Placement

### Inside VPC
- API Gateway (Regional endpoint)
- Lambda Functions (in private subnets)
- Aurora Database (in private subnets)
- Security Groups
- Network ACLs

### Outside VPC but in Region
- S3 Buckets (global service but region-specific)
- CloudWatch Logs
- CloudWatch Alarms

### Global Services
- Route 53 DNS
- CloudFront (if used)
- IAM Roles and Policies

## Network Security Layers

1. **VPC Level**
   - Network ACLs
   - Subnet segregation
   - Internet Gateway configuration

2. **Component Level**
   - Security Groups
   - IAM Roles
   - Service endpoints

3. **Application Level**
   - API Gateway authentication
   - Lambda security context
   - Database encryption

## Failover Network Path

1. **Normal Operation**
   ```
   User → Route 53 → Primary API Gateway → Primary Lambda → Primary Aurora
   ```

2. **During Failover**
   ```
   User → Route 53 → Standby API Gateway → Standby Lambda → Aurora Replica
   ```

This architecture follows AWS best practices for high availability and disaster recovery, with clear network boundaries and security zones, similar to the reference diagram you provided. Each component is placed in the appropriate network tier with proper security controls and replication paths.