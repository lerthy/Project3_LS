# Route53 DNS Failover Fix - API Gateway Endpoints

## Problem Identified

The Route53 failover configuration was using placeholder IP addresses for API Gateway endpoints, which is incorrect because:

1. **API Gateway doesn't provide static IP addresses** - It's a managed service with dynamic IPs
2. **Health checks would fail** - The fake IPs (1.2.3.4, 5.6.7.8) don't resolve to actual API endpoints
3. **Failover wouldn't work** - Route53 can't route traffic to non-existent IPs

## Incorrect Configuration (BEFORE)

```terraform
# ❌ WRONG - Using A records with fake IPs
resource "aws_route53_record" "api_failover" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "A"
  
  records = ["1.2.3.4"]  # Fake placeholder IP
  ttl     = 60
}
```

## Correct Configuration (AFTER)

```terraform
# ✅ CORRECT - Using CNAME records with actual API Gateway DNS names
resource "aws_route53_record" "api_failover" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "CNAME"
  
  records = [var.primary_api_dns]  # Real API Gateway URL
  ttl     = 60
}
```

## Changes Made

### 1. Updated Route53 Failover Records (`infra/modules/route53/failover.tf`)

**Changed from A records to CNAME records:**

```terraform
# Primary API failover record
resource "aws_route53_record" "api_failover" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "CNAME"  # Changed from "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }
  health_check_id = aws_route53_health_check.primary_api.id
  records         = [var.primary_api_dns]  # Uses DNS name instead of IP
  ttl             = 60
}

# Standby API failover record
resource "aws_route53_record" "api_failover_standby" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "CNAME"  # Changed from "A"

  set_identifier = "standby"
  failover_routing_policy {
    type = "SECONDARY"
  }
  health_check_id = aws_route53_health_check.standby_api.id
  records         = [var.standby_api_dns]  # Uses DNS name instead of IP
  ttl             = 60
}
```

### 2. Removed IP Variables (`infra/modules/route53/variables.tf`)

**Deleted unnecessary variables:**
- `primary_api_ip` - No longer needed
- `standby_api_ip` - No longer needed

**Kept essential variables:**
- `primary_api_dns` - Real API Gateway DNS name
- `standby_api_dns` - Real standby API Gateway DNS name

### 3. Updated Module Call (`infra/main.tf`)

```terraform
# Before ❌
module "route53" {
  source = "./modules/route53"
  
  primary_api_dns = module.api_gateway.api_gateway_url
  standby_api_dns = module.api_gateway_standby.api_endpoint
  primary_api_ip  = "1.2.3.4"  # Fake IP
  standby_api_ip  = "5.6.7.8"  # Fake IP
  route53_zone_id = var.route53_zone_id
}

# After ✅
module "route53" {
  source = "./modules/route53"
  
  primary_api_dns = module.api_gateway.api_gateway_url
  standby_api_dns = module.api_gateway_standby.api_endpoint
  route53_zone_id = var.route53_zone_id
}
```

## How It Works Now

### DNS Resolution Flow

1. **User requests**: `api.project3.com`
2. **Route53 checks**: Primary API Gateway health
3. **If healthy**: Returns CNAME pointing to primary API Gateway DNS
4. **If unhealthy**: Returns CNAME pointing to standby API Gateway DNS

### Health Check Configuration

```terraform
resource "aws_route53_health_check" "primary_api" {
  fqdn              = var.primary_api_dns  # e.g., "abc123.execute-api.eu-north-1.amazonaws.com"
  type              = "HTTPS"
  resource_path     = "/contact"
  port              = 443
  request_interval  = 30
  failure_threshold = 3
}
```

## DNS Caching Considerations

- **TTL set to 60 seconds** for fast failover
- Users may experience up to 60 seconds of caching before seeing failover
- Health checks run every 30 seconds
- Failover triggers after 3 consecutive failures (90 seconds total)

**Total maximum failover time**: ~150 seconds (2.5 minutes)

## Actual DNS Names Used

### Primary Region (eu-north-1)
```
API Gateway URL: https://[random-id].execute-api.eu-north-1.amazonaws.com/dev
DNS Name: [random-id].execute-api.eu-north-1.amazonaws.com
```

### Standby Region (us-west-2)
```
API Gateway URL: https://[random-id].execute-api.us-west-2.amazonaws.com/dev
DNS Name: [random-id].execute-api.us-west-2.amazonaws.com
```

## Testing the Failover

### Manual Testing Steps

1. **Check primary health**:
   ```bash
   curl -I https://api.project3.com/contact
   ```

2. **Simulate primary failure** (disable primary API Gateway)

3. **Wait for health check failures** (90 seconds = 3 × 30-second intervals)

4. **Verify failover**:
   ```bash
   dig api.project3.com CNAME
   # Should show standby API Gateway DNS name
   ```

5. **Test standby API**:
   ```bash
   curl -I https://api.project3.com/contact
   # Should return 200 from standby region
   ```

### Automated Testing

Use Route53 Application Recovery Controller (ARC) for:
- Automated failover testing
- Readiness checks
- Zonal shift capabilities

## Benefits of This Fix

✅ **Correct DNS Resolution** - Uses actual API Gateway endpoints
✅ **Working Health Checks** - Can properly monitor API availability
✅ **Automated Failover** - Route53 switches to standby when primary fails
✅ **No Manual Intervention** - Failover happens automatically
✅ **Fast Recovery** - 60-second TTL enables quick DNS propagation

## Important Notes

### CNAME Limitations

⚠️ **CNAME records cannot be used at the zone apex (root domain)**

If you want to use the root domain (e.g., `project3.com` instead of `api.project3.com`):
- Use **Route53 ALIAS records** instead
- Point to API Gateway custom domain name
- Requires ACM certificate and custom domain setup

### Alternative: ALIAS Records

For better performance and AWS integration:

```terraform
resource "aws_route53_record" "api_failover" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.custom.cloudfront_zone_id
    evaluate_target_health = true
  }
  
  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }
}
```

**ALIAS records benefits**:
- No TTL (Route53 manages caching)
- Can be used at zone apex
- Free queries (no charge for ALIAS queries)
- Better performance

## Verification Checklist

- [x] Removed fake IP addresses (1.2.3.4, 5.6.7.8)
- [x] Changed A records to CNAME records
- [x] Updated variables to use DNS names only
- [x] Removed unnecessary IP variables
- [x] Updated module calls in main.tf
- [x] Health checks point to real API Gateway FQDNs
- [x] TTL set to 60 seconds for fast failover
- [x] Failover threshold set to 3 consecutive failures

## Related Documentation

- [CloudFront Origin Failover Implementation](./cloudfront-origin-failover.md)
- [Cross-Region Warm Standby Architecture](./cross-region-warm-standby-architecture.md)
- [Reliability Architecture](./reliability-architecture.md)

---

**Issue Fixed By**: Colleague's observation
**Date**: October 6, 2025
**Impact**: Critical - Enables actual DNS failover for disaster recovery
