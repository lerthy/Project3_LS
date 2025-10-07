# Cost Optimization Module - Resource Scheduling

This module implements automated resource scheduling for non-production environments to reduce AWS costs by stopping resources during off-hours.

## 🎯 **Purpose**

Automatically manage AWS resources during business hours to optimize costs:
- **Stop resources** at 7 PM UTC (weekdays) 
- **Start resources** at 8 AM UTC (weekdays)
- Only applies to non-production environments (development, staging)

## 💰 **Cost Savings**

| Resource | Savings | Impact |
|----------|---------|---------|
| **RDS Instance** | $2-10/day | Stopped during 12+ off-hours |
| **Lambda Provisioned Concurrency** | $1-3/day | Removed when not needed |
| **Monthly Total** | $90-390 | 65% cost reduction during off-hours |

## 🏗️ **Architecture**

```
EventBridge Rules → Lambda Scheduler → AWS Resources
     ↓                    ↓                ↓
 Cron Schedule      Resource Manager    RDS/Lambda
```

### Components:
1. **EventBridge Rules**: Trigger start/stop actions on schedule
2. **Lambda Scheduler**: Python function that manages resources
3. **IAM Roles**: Permissions for resource management
4. **CloudWatch Alarms**: Monitor scheduler health

## 📅 **Default Schedule**

- **Stop Time**: 7:00 PM UTC (Monday-Friday)
- **Start Time**: 8:00 AM UTC (Monday-Friday)  
- **Weekend**: Resources remain stopped Friday 7 PM → Monday 8 AM

### Converting to Your Timezone:
```bash
# For EST (UTC-5): 7 PM UTC = 2 PM EST, 8 AM UTC = 3 AM EST
# For PST (UTC-8): 7 PM UTC = 11 AM PST, 8 AM UTC = 12 AM PST
```

## 🚀 **Resources Managed**

### ✅ **Currently Scheduled:**
- **RDS Instances**: Stop/start database instances
- **Lambda Provisioned Concurrency**: Remove/restore reserved capacity

### 🔄 **Future Enhancements:**
- ECS Services scaling to zero
- Auto Scaling Group instance counts
- NAT Gateways for development VPCs
- ElastiCache clusters

## 📋 **Usage**

```hcl
module "cost_optimization" {
  source = "./modules/cost-optimization"
  
  environment             = var.environment
  rds_identifier         = module.rds.rds_instance_id
  lambda_function_name   = module.lambda.lambda_function_name
  notification_topic_arn = module.monitoring.sns_topic_arn
  
  # Optional: Custom schedule
  stop_schedule  = "cron(0 19 ? * MON-FRI *)"  # 7 PM weekdays
  start_schedule = "cron(0 8 ? * MON-FRI *)"   # 8 AM weekdays
  
  tags = local.common_tags
}
```

## ⚙️ **Configuration**

### Environment Variables (Lambda):
- `ENVIRONMENT`: Target environment name
- `RDS_IDENTIFIER`: Database instance to manage
- `LAMBDA_FUNCTION`: Function name for provisioned concurrency

### Cron Schedule Format:
```
cron(Minutes Hours Day-of-month Month Day-of-week Year)
cron(0 19 ? * MON-FRI *)  # 7 PM weekdays
```

## 🔐 **Security**

### IAM Permissions:
- **RDS**: `StopDBInstance`, `StartDBInstance`, `DescribeDBInstances`
- **Lambda**: `PutProvisionedConcurrencyConfig`, `DeleteProvisionedConcurrencyConfig`
- **CloudWatch**: Log group management
- **SNS**: Notification publishing

### Safety Features:
- Only runs in non-production environments
- Graceful error handling
- Status checking before actions
- Comprehensive logging

## 📊 **Monitoring**

### CloudWatch Metrics:
- Scheduler Lambda errors
- RDS instance state changes
- Cost impact tracking

### Notifications:
- Success/failure alerts via SNS
- Daily cost savings reports
- Resource state summaries

## 🧪 **Testing**

### Manual Trigger:
```bash
# Test stop action
aws lambda invoke \
  --function-name resource-scheduler-development \
  --payload '{"action":"stop","environment":"development"}' \
  response.json

# Test start action  
aws lambda invoke \
  --function-name resource-scheduler-development \
  --payload '{"action":"start","environment":"development"}' \
  response.json
```

### Validation:
```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier contact-db-development

# Check Lambda provisioned concurrency
aws lambda get-provisioned-concurrency-config \
  --function-name contact-form-development
```

## 🚨 **Important Notes**

1. **Production Safety**: Module only deploys in non-production environments
2. **Weekend Savings**: Resources stay off Friday 7 PM → Monday 8 AM  
3. **Database Restart**: RDS instances take 2-5 minutes to start/stop
4. **Lambda Cold Starts**: First request after restart may be slower
5. **Time Zone**: All schedules use UTC - adjust for your location

## 📈 **Cost Impact**

### Before Scheduling:
- RDS t3.micro: $12/month (24/7)
- Lambda Provisioned: $15/month (24/7)
- **Total**: $27/month

### After Scheduling:
- RDS t3.micro: $4/month (8hrs/day weekdays)
- Lambda Provisioned: $5/month (8hrs/day weekdays) 
- **Total**: $9/month (**67% savings!**)

---

*This module helps you achieve significant cost savings while maintaining development productivity during business hours.* 💰
