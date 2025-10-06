# CloudFront Origin Failover Architecture

## Overview
This document explains the CloudFront origin failover implementation that provides automatic website failover between primary (eu-north-1) and standby (us-west-2) S3 buckets.

## Architecture Diagram

```
                    Users
                      ↓
              [CloudFront CDN]
              (Global Distribution)
                      ↓
          ┌───────────┴───────────┐
          │   Origin Group        │
          │   (Auto Failover)     │
          └───────────┬───────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
    [PRIMARY]                   [STANDBY]
        │                           │
   S3 Bucket                   S3 Bucket
  (eu-north-1)                (us-west-2)
  my-website-bucket      project3-website-standby
        │                           │
        └──────── Replication ──────┘
                (Automatic)
```

## How It Works

### Normal Operation
1. **CloudFront** serves content globally from edge locations
2. **Primary Origin**: CloudFront fetches from S3 bucket in eu-north-1
3. **S3 Replication**: Continuously replicates to standby bucket in us-west-2
4. **Standby Ready**: Standby bucket is kept in sync but not actively serving traffic

### During Primary Region Failure
1. **Failure Detection**: CloudFront detects errors from primary S3 bucket
   - HTTP status codes: 403, 404, 500, 502, 503, 504
2. **Automatic Failover**: CloudFront switches to standby origin (us-west-2)
3. **Seamless Service**: Users continue to access the website without interruption
4. **CloudFront Cache**: Edge locations continue serving cached content during transition

### Failback to Primary
1. **Primary Recovery**: When primary bucket becomes available again
2. **CloudFront Retry**: CloudFront automatically retries primary origin
3. **Automatic Failback**: Once primary responds successfully, traffic returns to primary
4. **Replication Catch-up**: S3 replication syncs any changes made during failover

## Configuration Details

### Origin Group Configuration
```terraform
origin_group {
  origin_id = "s3-origin-group-with-failover"
  
  failover_criteria {
    status_codes = [403, 404, 500, 502, 503, 504]
  }
  
  member {
    origin_id = "primary-s3-origin"  # eu-north-1
  }
  
  member {
    origin_id = "standby-s3-origin"  # us-west-2
  }
}
```

### S3 Replication Settings
- **Source**: my-website-bucket-project3-eunorth1-unique-sb (eu-north-1)
- **Destination**: project3-website-standby (us-west-2)
- **Storage Class**: STANDARD_IA (cost-optimized for standby)
- **Replication**: Real-time, automatic
- **Versioning**: Enabled on both buckets

### CloudFront Behavior
- **Primary Origin**: Always attempted first
- **Failover Trigger**: Any 4xx/5xx error from primary
- **Failover Time**: Typically 10-30 seconds
- **User Impact**: Minimal - cached content continues to serve

## Complete Disaster Recovery Stack

With this implementation, you now have **full-stack failover**:

### 1. **Website Layer** ✅ (NEW)
   - CloudFront → Primary S3 (eu-north-1)
   - CloudFront → Standby S3 (us-west-2) [Automatic Failover]

### 2. **API Layer** ✅
   - Route53 → Primary API Gateway (eu-north-1)
   - Route53 → Standby API Gateway (us-west-2) [DNS Failover]

### 3. **Compute Layer** ✅
   - Primary Lambda (eu-north-1)
   - Standby Lambda (us-west-2)

### 4. **Database Layer** ✅
   - Primary RDS (eu-north-1) - Multi-AZ
   - Standby RDS (us-west-2) - DMS Replication

## Traffic Flow Comparison

### Before (Partial Failover)
```
Website:  CloudFront → Primary S3 → ❌ FAILS (no failover)
API:      Route53 → Primary API → Standby API ✅ (DNS failover works)
Database: Primary RDS → Standby RDS ✅ (DMS replication works)
```

### After (Complete Failover) ✅
```
Website:  CloudFront → Primary S3 → Standby S3 ✅ (origin failover works)
API:      Route53 → Primary API → Standby API ✅ (DNS failover works)
Database: Primary RDS → Standby RDS ✅ (DMS replication works)
```

## Recovery Time Objective (RTO)

| Component | Failover Method | RTO | Automatic |
|-----------|----------------|-----|-----------|
| Website (S3) | CloudFront Origin Group | 10-30s | ✅ Yes |
| API Gateway | Route53 DNS Failover | 60s | ✅ Yes |
| Lambda | Pre-warmed standby | 0s | ✅ Yes |
| RDS Database | DMS Replication + Manual Promotion | 5-15m | ⚠️ Semi-auto |

**Overall Application RTO**: < 1 minute for website and API, < 15 minutes for full recovery

## Recovery Point Objective (RPO)

| Data Type | Replication Method | RPO | Data Loss Risk |
|-----------|-------------------|-----|----------------|
| Static Website Files | S3 Cross-Region Replication | < 1 minute | Minimal |
| API State | Stateless Lambda | 0s | None |
| Database Records | DMS Change Data Capture | < 5 minutes | Low |

**Overall Application RPO**: < 5 minutes

## Cost Implications

### Additional Costs (Production Only)
- **S3 Standby Bucket**: ~$5-10/month (STANDARD_IA storage class)
- **S3 Replication**: Data transfer ~$0.02/GB
- **CloudFront**: No additional cost (same distribution serves both origins)

### Cost Optimization
- Origin failover only enabled in production (`var.environment == "production"`)
- Standby bucket uses STANDARD_IA storage class (50% cheaper than STANDARD)
- CloudFront edge caching reduces origin requests

## Testing Failover

### Manual Test Procedure
1. **Simulate Primary Failure**: 
   ```bash
   # Temporarily block CloudFront OAI access to primary bucket
   aws s3api put-bucket-policy --bucket my-website-bucket-project3 --policy '{
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Deny",
       "Principal": "*",
       "Action": "s3:GetObject",
       "Resource": "arn:aws:s3:::my-website-bucket-project3/*"
     }]
   }'
   ```

2. **Verify Failover**:
   - Access website via CloudFront URL
   - Should automatically serve from standby bucket
   - Check CloudFront access logs for origin switch

3. **Restore Primary**:
   ```bash
   # Remove blocking policy
   aws s3api delete-bucket-policy --bucket my-website-bucket-project3
   ```

### Monitoring
- **CloudWatch Metrics**: Monitor `OriginLatency` and `ErrorRate` per origin
- **CloudFront Logs**: Check which origin served each request
- **S3 Metrics**: Monitor replication status and lag

## Troubleshooting

### Failover Not Working
- ✅ Check: Is `enable_origin_failover = true` in production?
- ✅ Check: Is S3 replication enabled and working?
- ✅ Check: Does standby bucket have CloudFront OAI policy?
- ✅ Check: Are both buckets in correct regions?

### Replication Lag
- Check S3 replication metrics in CloudWatch
- Verify replication role has correct permissions
- Check for versioning enabled on both buckets

### Higher Costs Than Expected
- Verify environment is set correctly (failover only in production)
- Check S3 storage class is STANDARD_IA on standby
- Monitor data transfer costs

## Security Considerations

1. **Standby Bucket Access**: Only CloudFront OAI has read access
2. **Public Access**: Blocked on both primary and standby buckets
3. **Encryption**: Both buckets use server-side encryption (AES-256)
4. **Versioning**: Enabled for replication and recovery

## Best Practices

1. **Regular Testing**: Test failover monthly in production
2. **Monitor Replication**: Set up CloudWatch alarms for replication lag
3. **Cost Monitoring**: Track S3 and data transfer costs
4. **Documentation**: Keep runbooks updated for failover procedures
5. **Alerting**: Set up SNS notifications for failover events

## Related Documentation
- [Cross-Region Warm Standby Architecture](./cross-region-warm-standby-architecture.md)
- [Reliability Architecture](./reliability-architecture.md)
- [RTO/RPO Implementation](./rto-rpo-implementation-summary.md)
