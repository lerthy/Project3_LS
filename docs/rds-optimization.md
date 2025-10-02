# RDS Optimization for E-commerce Workload

## Current vs Optimized Configuration

### 1. Instance Type Optimization
```hcl
# BEFORE: db.t3.micro (1 vCPU, 1 GB RAM)
instance_class = "db.t3.micro"

# AFTER: db.t3.small (2 vCPU, 2 GB RAM) - Better for e-commerce workload
instance_class = "db.t3.small"
```

### 2. Storage Optimization
```hcl
# BEFORE: Fixed 20GB storage
allocated_storage     = 20
storage_type         = "gp2"

# AFTER: Auto-scaling storage with better IOPS
allocated_storage     = 20
max_allocated_storage = 100  # Allow growth up to 100GB
storage_type         = "gp3"
iops                 = 3000  # Consistent IOPS for better performance
```

### 3. Parameter Group Optimization
```hcl
resource "aws_db_parameter_group" "postgres_ecommerce" {
  name   = "postgres13-ecommerce"
  family = "postgres13"

  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/4}"    # 25% of instance memory
  }

  parameter {
    name  = "max_connections"
    value = "200"    # Higher connection limit for e-commerce traffic
  }

  parameter {
    name  = "work_mem"
    value = "16384"  # 16MB for better query performance
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "128000" # 128MB for faster maintenance operations
  }

  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory*3/4}"  # 75% of instance memory
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1"    # Optimized for SSD storage
  }
}
```

### 4. Backup and Recovery Optimization
```hcl
# Enhanced backup configuration for 1h RPO
resource "aws_db_instance" "contact_db" {
  # ... other configurations ...
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  
  # Enable performance insights for better monitoring
  performance_insights_enabled    = true
  performance_insights_retention_period = 7
  
  # Enhanced monitoring for better visibility
  monitoring_interval            = 30  # 30-second intervals instead of 60
  
  # Auto minor version upgrade for security patches
  auto_minor_version_upgrade     = true
  
  # Maintenance window during off-peak hours
  maintenance_window             = "Mon:04:00-Mon:05:00"
  
  # Enhanced durability
  storage_encrypted             = true
  multi_az                     = true
}
```

### 5. CloudWatch Alarms for E-commerce SLAs
```hcl
# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.contact_db.id
  }
}

# Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10737418240" # 10GB in bytes
  alarm_description   = "RDS free storage space is low"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.contact_db.id
  }
}

# Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "150"  # 75% of max connections
  alarm_description   = "RDS connection count is high"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.contact_db.id
  }
}
```

## Key Optimizations for E-commerce Workload

1. **Instance Upgrade**:
   - Moved from db.t3.micro to db.t3.small
   - Double the CPU and RAM for better performance
   - Better suited for e-commerce traffic patterns

2. **Storage Improvements**:
   - Enabled storage auto-scaling
   - Upgraded to GP3 for better IOPS
   - Set reasonable growth limits

3. **Performance Tuning**:
   - Custom parameter group optimized for e-commerce
   - Increased connection limits
   - Better memory allocation for queries
   - Optimized cache settings

4. **Monitoring Enhancements**:
   - Enabled Performance Insights
   - 30-second monitoring intervals
   - Added specific e-commerce focused alarms
   - Better visibility into performance metrics

5. **RPO/RTO Optimizations**:
   - Multi-AZ deployment maintained
   - Enhanced backup settings
   - Faster monitoring for quicker issue detection
   - Storage encryption for data protection

These optimizations are specifically designed to:
- Meet your 1h RPO requirement through frequent backups and replication
- Support your 4h RTO with Multi-AZ and quick failover
- Handle e-commerce workload patterns
- Provide better monitoring and alerting
- Enable growth with auto-scaling
- Maintain security with encryption

Would you like me to:
1. Implement these optimizations in your Terraform code?
2. Add more specific monitoring for e-commerce patterns?
3. Add additional performance tuning parameters?