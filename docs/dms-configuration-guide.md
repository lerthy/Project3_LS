# DMS Configuration Guide

## Circular Dependency Issue Resolution

### Problem
The RDS module has a DMS target endpoint that requires the standby RDS endpoint address. However, this creates a circular dependency:
- `module.rds` needs `module.rds_standby.standby_db_endpoint` for DMS target
- `module.rds_standby` needs `module.rds.generated_password` for database password

### Solution
The DMS target endpoint initially uses a placeholder value, then needs to be updated after both RDS instances are created.

## Two-Step Deployment Process

### Step 1: Initial Deployment
```bash
# First deployment - DMS will use placeholder endpoint
terraform apply
```

This creates:
- ✅ Primary RDS instance (eu-north-1)
- ✅ Standby RDS instance (us-west-2)  
- ⚠️ DMS replication instance (but target endpoint uses placeholder)

### Step 2: Update DMS Target Endpoint
After both RDS instances are created, you have two options:

#### Option A: Manual Update via AWS Console
1. Go to AWS DMS Console
2. Find the target endpoint: `target-endpoint`
3. Modify the server address to the actual standby RDS endpoint
4. Test the connection
5. Start the replication task

#### Option B: Terraform Update (Manual Intervention Required)
1. After initial `terraform apply`, note the standby RDS endpoint from outputs
2. Uncomment the `standby_rds_address` line in `infra/main.tf`:
   ```terraform
   module "rds" {
     # ... other config ...
     standby_rds_address = module.rds_standby.standby_db_endpoint
   }
   ```
3. Run `terraform apply` again to update the DMS target endpoint

## Current Configuration

### RDS Module (infra/modules/rds/variables.tf)
```terraform
variable "standby_rds_address" {
  description = "Address of the standby RDS instance in us-west-2"
  type        = string
  default     = "placeholder.us-west-2.rds.amazonaws.com"  # Placeholder to avoid circular dependency
}
```

### Main Configuration (infra/main.tf)
```terraform
module "rds" {
  # ...
  dms_subnet_ids      = data.aws_subnets.default_vpc_subnets.ids
  dms_subnet_group_id = "dms-replication-subnet-group"
  # standby_rds_address not set - uses default placeholder
  # Will be updated in Step 2 after standby RDS is created
}
```

## Alternative: Separate DMS Module (Future Enhancement)

For a cleaner solution, consider creating a separate DMS module that depends on both RDS instances:

```terraform
# infra/main.tf (future enhancement)
module "dms_replication" {
  source = "./modules/dms"
  
  source_db_endpoint = module.rds.rds_endpoint
  target_db_endpoint = module.rds_standby.standby_db_endpoint
  source_db_username = var.db_username
  source_db_password = module.rds.generated_password
  
  depends_on = [module.rds, module.rds_standby]
}
```

This would eliminate the circular dependency issue entirely.

## Verification

After DMS is properly configured, verify replication:

```bash
# Check DMS replication task status
aws dms describe-replication-tasks --filters Name=replication-task-id,Values=rds-to-standby

# Verify data is replicating
# Connect to standby RDS and check table counts match primary
```

## Important Notes

1. **Production Environment Only**: DMS replication is only created when `var.environment == "production"`
2. **Initial Placeholder**: The first deployment uses a placeholder endpoint to avoid circular dependency
3. **Manual Update Required**: After initial deployment, update the DMS target endpoint manually or via second terraform apply
4. **Data Consistency**: Ensure DMS replication is working before considering the disaster recovery setup complete
