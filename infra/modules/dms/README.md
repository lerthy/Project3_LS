# DMS Module

This module manages AWS Database Migration Service (DMS) for cross-region database replication from primary RDS to standby RDS.

## Purpose

This module is **separate from the RDS module** to avoid circular dependency issues. It depends on both the primary and standby RDS instances being created first.

## Features

- ✅ DMS Replication Instance
- ✅ Source Endpoint (Primary RDS)
- ✅ Target Endpoint (Standby RDS)
- ✅ Replication Task with Change Data Capture (CDC)
- ✅ CloudWatch Logging
- ✅ Automatic schema replication
- ✅ Ongoing data synchronization

## Usage

```hcl
module "dms_replication" {
  source = "./modules/dms"
  
  # Environment
  environment = "production"
  
  # DMS Instance Configuration
  replication_instance_id    = "rds-replication-instance"
  replication_instance_class = "dms.t3.small"
  allocated_storage          = 50
  multi_az                   = false
  
  # Subnet Configuration
  subnet_group_id = "dms-replication-subnet-group"
  subnet_ids      = ["subnet-xxx", "subnet-yyy"]
  
  # Source Database (Primary RDS)
  source_db_endpoint  = module.rds.rds_address
  source_db_port      = 5432
  source_db_username  = var.db_username
  source_db_password  = module.rds.generated_password
  
  # Target Database (Standby RDS)
  target_db_endpoint  = module.rds_standby.standby_db_endpoint
  target_db_port      = 5432
  target_db_username  = var.db_username
  target_db_password  = module.rds_standby.generated_password
  
  # Database Configuration
  database_name = var.db_name
  
  tags = local.common_tags
  
  # IMPORTANT: Must depend on both RDS instances
  depends_on = [module.rds, module.rds_standby]
}
```

## Why Separate Module?

### The Problem
Previously, DMS configuration was inside the RDS module, which created a circular dependency:

```
module.rds → needs → module.rds_standby.endpoint (for DMS target)
module.rds_standby → needs → module.rds.password (for database creation)
```

This caused Terraform validation errors.

### The Solution
By creating a **separate DMS module** that depends on both RDS instances:

```
module.rds → creates primary RDS ✅
module.rds_standby → creates standby RDS ✅
module.dms → creates replication (depends on both) ✅
```

No circular dependency! ✅

## Replication Configuration

### Migration Type
- **CDC (Change Data Capture)**: Ongoing replication of all changes

### Table Mappings
- Replicates **all schemas** and **all tables**
- Can be customized for specific tables

### Replication Settings
- **Full Load**: DROP_AND_CREATE tables
- **Error Handling**: LOG_ERROR policy
- **Logging**: Enabled for all components
- **LOB Support**: Limited size LOB mode (32 MB chunks)

## Monitoring

The module creates a CloudWatch Log Group:
```
/aws/dms/rds-to-standby
```

Monitor replication status:
```bash
# Check replication task status
aws dms describe-replication-tasks \
  --filters Name=replication-task-id,Values=rds-to-standby

# View replication metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DMS \
  --metric-name CDCLatencySource \
  --dimensions Name=ReplicationInstanceIdentifier,Value=rds-replication-instance
```

## Outputs

| Output | Description |
|--------|-------------|
| `replication_instance_arn` | ARN of DMS replication instance |
| `replication_instance_id` | ID of DMS replication instance |
| `source_endpoint_arn` | ARN of source endpoint |
| `target_endpoint_arn` | ARN of target endpoint |
| `replication_task_arn` | ARN of replication task |
| `replication_task_id` | ID of replication task |

## Cost Considerations

- **DMS Instance**: ~$20-30/month (dms.t3.small)
- **Data Transfer**: Cross-region charges apply
- **Storage**: 50 GB included

## Troubleshooting

### Replication Task Fails to Start
1. Verify both RDS instances are running
2. Check security groups allow DMS access
3. Verify credentials are correct
4. Check CloudWatch logs for errors

### Replication Lag
1. Check source database load
2. Verify DMS instance size is adequate
3. Monitor network latency between regions
4. Check for table locks on source

### Connection Issues
1. Ensure DMS is in the correct VPC/subnets
2. Verify security groups allow port 5432
3. Test endpoint connections in DMS console
4. Check RDS parameter groups allow replication
