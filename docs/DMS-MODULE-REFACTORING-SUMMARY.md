# DMS Module Refactoring - Circular Dependency Resolution

## Problem Solved

### Original Issue: Circular Dependency
The infrastructure had a circular dependency that prevented Terraform from validating:

```
module.rds → needed → module.rds_standby.endpoint (for DMS target)
module.rds_standby → needed → module.rds.generated_password
```

This created an infinite loop that Terraform couldn't resolve.

## Solution Implemented

### Moved DMS to Separate Module ✅

Created a **dedicated DMS module** (`infra/modules/dms/`) that depends on both RDS instances:

```
1. module.rds → Creates primary RDS ✅
2. module.rds_standby → Creates standby RDS ✅  
3. module.dms_replication → Creates DMS replication (depends on both) ✅
```

**No circular dependency!** ✅

## Changes Made

### 1. Created New DMS Module
**Location**: `/infra/modules/dms/`

**Files Created**:
- `main.tf` - DMS resources (instance, endpoints, replication task, IAM roles)
- `variables.tf` - All DMS configuration variables
- `outputs.tf` - DMS outputs (instance ARN, task ARN, etc.)
- `README.md` - Comprehensive documentation

**Features**:
- ✅ DMS Replication Instance
- ✅ Source Endpoint (Primary RDS)
- ✅ Target Endpoint (Standby RDS)
- ✅ Replication Task with CDC (Change Data Capture)
- ✅ IAM roles and policies for VPC access
- ✅ CloudWatch logging
- ✅ Production-only deployment (conditional)

### 2. Cleaned Up RDS Module
**Removed from `/infra/modules/rds/`**:
- ❌ All DMS resources (instance, endpoints, tasks)
- ❌ DMS IAM roles and policies
- ❌ DMS-related variables (`dms_subnet_ids`, `dms_subnet_group_id`, `standby_rds_address`)
- ❌ DMS outputs (`dms_task_id`, `dms_task_arn`)

**What Remains**:
- ✅ RDS database instance
- ✅ Security groups
- ✅ KMS encryption
- ✅ Monitoring role
- ✅ Parameter groups

### 3. Updated Main Infrastructure
**File**: `/infra/main.tf`

**Removed from RDS module call**:
```terraform
# OLD - REMOVED
dms_subnet_ids      = data.aws_subnets.default_vpc_subnets.ids
dms_subnet_group_id = "dms-replication-subnet-group"
standby_rds_address = module.rds_standby.standby_db_endpoint
```

**Added new DMS module**:
```terraform
module "dms_replication" {
  source = "./modules/dms"
  count  = var.environment == "production" ? 1 : 0

  # Source Database (Primary RDS)
  source_db_endpoint = module.rds.rds_address
  source_db_password = module.rds.generated_password
  
  # Target Database (Standby RDS)
  target_db_endpoint = module.rds_standby.standby_db_endpoint
  target_db_password = module.rds.generated_password  # Same password
  
  # CRITICAL: Depends on both RDS instances
  depends_on = [module.rds, module.rds_standby]
}
```

## Validation Results

### Before Fix ❌
```bash
$ terraform validate
Error: Cycle: module.rds_standby → module.rds → module.rds_standby
```

### After Fix ✅
```bash
$ terraform validate
Success! The configuration is valid.
```

## Architecture Benefits

### Before (Circular Dependency)
```
┌─────────────────────────────────────────┐
│         module.rds                     │
│  ┌──────────────────────────────────┐  │
│  │ - RDS Instance                   │  │
│  │ - DMS Instance                   │  │
│  │ - DMS Source Endpoint            │  │
│  │ - DMS Target Endpoint  ←──────┐  │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
                    ↓                     ↑
                    ↓                     ↑
                    ↓                     ↑
┌─────────────────────────────────────────┐
│      module.rds_standby                │
│  ┌──────────────────────────────────┐  │
│  │ - Standby RDS Instance           │  │
│  │ - Uses generated_password ───────┘  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘

❌ CIRCULAR DEPENDENCY!
```

### After (Clean Separation)
```
┌─────────────────────────┐
│     module.rds          │
│  - RDS Instance         │
│  - Security Groups      │
│  - KMS Encryption       │
└─────────────────────────┘
            ↓
            ↓
┌─────────────────────────┐
│  module.rds_standby     │
│  - Standby RDS          │
│  - Uses primary pwd     │
└─────────────────────────┘
            ↓
            ↓
┌─────────────────────────┐
│  module.dms_replication │
│  - DMS Instance         │
│  - Source Endpoint      │
│  - Target Endpoint      │
│  - Replication Task     │
│  depends_on: [rds,      │
│   rds_standby]          │
└─────────────────────────┘

✅ NO CIRCULAR DEPENDENCY!
```

## Deployment Flow

### Production Deployment (environment = "production")
1. **Step 1**: Primary RDS created (eu-north-1)
2. **Step 2**: Standby RDS created (us-west-2) using primary password
3. **Step 3**: DMS module creates replication infrastructure
4. **Step 4**: Data replication begins automatically

### Development Deployment (environment = "development")
1. **Step 1**: Primary RDS created
2. **Step 2**: Standby RDS created
3. **Step 3**: DMS module skipped (count = 0)

## Testing

### Validation Test ✅
```bash
cd infra
terraform init -upgrade
terraform validate
# Result: Success! The configuration is valid.
```

### Plan Test (Next Step)
```bash
terraform plan
# Should show clean dependency graph
```

## Related Files Modified

1. `/infra/modules/dms/main.tf` - Created
2. `/infra/modules/dms/variables.tf` - Created
3. `/infra/modules/dms/outputs.tf` - Created
4. `/infra/modules/dms/README.md` - Created
5. `/infra/modules/rds/main.tf` - Removed DMS resources
6. `/infra/modules/rds/variables.tf` - Removed DMS variables
7. `/infra/modules/rds/outputs.tf` - Removed DMS outputs
8. `/infra/main.tf` - Updated RDS module call, added DMS module
9. `/docs/dms-configuration-guide.md` - Updated documentation

## Removed Files

- Deleted `/infra/modules/rds-replica/` - Unused module
- Removed DMS JSON files from RDS module (moved to DMS module)

## Cost Impact

**No change in costs** - Same DMS resources, just better organized:
- DMS Instance: ~$20-30/month (dms.t3.small)
- Only deployed in production environment

## Next Steps

1. ✅ Terraform validate - PASSED
2. ⏳ Terraform plan - Review changes
3. ⏳ Terraform apply - Deploy infrastructure
4. ⏳ Verify DMS replication is working
5. ⏳ Monitor CloudWatch logs for DMS

## Key Learnings

1. **Circular dependencies** can be resolved by extracting shared resources into separate modules
2. **Module dependencies** should be managed through explicit `depends_on` when needed
3. **Terraform module design** should follow single responsibility principle
4. **Sensitive outputs** (passwords) can be safely passed between modules
5. **Conditional resources** (`count`) work well with module separation

## Success Criteria

- ✅ Terraform validates successfully
- ✅ No circular dependency errors
- ✅ DMS resources properly organized
- ✅ Clean module boundaries
- ✅ Production-only DMS deployment
- ✅ Comprehensive documentation
