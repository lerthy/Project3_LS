# DMS Module - Separate from RDS to avoid circular dependencies
# This module handles cross-region database replication from primary to standby RDS

# IAM Role for DMS to access VPC resources
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role-project3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "dms-vpc-role-project3"
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role_policy" "dms_vpc_policy" {
  name = "dms-vpc-custom-policy"
  role = aws_iam_role.dms_vpc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# DMS Replication Subnet Group
resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_id          = var.subnet_group_id
  replication_subnet_group_description = "DMS replication subnet group for cross-region RDS replication"
  subnet_ids                           = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.subnet_group_id}"
  })

  depends_on = [aws_iam_role.dms_vpc_role]
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "rds_replication" {
  replication_instance_id   = var.replication_instance_id
  replication_instance_class = var.replication_instance_class
  allocated_storage          = var.allocated_storage
  publicly_accessible        = false
  multi_az                   = var.multi_az

  replication_subnet_group_id = aws_dms_replication_subnet_group.dms_subnet_group.id

  tags = merge(var.tags, {
    Name = "${var.replication_instance_id}"
  })
}

# Source Endpoint (Primary RDS)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "source-endpoint-primary-rds"
  endpoint_type = "source"
  engine_name   = "postgres"
  username      = var.source_db_username
  password      = var.source_db_password
  server_name   = var.source_db_endpoint
  port          = var.source_db_port
  database_name = var.database_name
  ssl_mode      = "require"

  tags = merge(var.tags, {
    Name = "source-endpoint-primary-rds"
  })
}

# Target Endpoint (Standby RDS)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "target-endpoint-standby-rds"
  endpoint_type = "target"
  engine_name   = "postgres"
  username      = var.target_db_username
  password      = var.target_db_password
  server_name   = var.target_db_endpoint
  port          = var.target_db_port
  database_name = var.database_name
  ssl_mode      = "require"

  tags = merge(var.tags, {
    Name = "target-endpoint-standby-rds"
  })
}

# DMS Replication Task
resource "aws_dms_replication_task" "rds_to_standby" {
  replication_task_id       = var.replication_task_id
  migration_type            = "cdc" # Change Data Capture for ongoing replication
  replication_instance_arn  = aws_dms_replication_instance.rds_replication.replication_instance_arn
  source_endpoint_arn       = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn       = aws_dms_endpoint.target.endpoint_arn
  
  table_mappings            = jsonencode({
    "rules": [
      {
        "rule-type": "selection",
        "rule-id": "1",
        "rule-name": "1",
        "object-locator": {
          "schema-name": "%",
          "table-name": "%"
        },
        "rule-action": "include"
      }
    ]
  })
  
  replication_task_settings = jsonencode({
    "TargetMetadata": {
      "TargetSchema": "",
      "SupportLobs": true,
      "FullLobMode": false,
      "LobChunkSize": 64,
      "LimitedSizeLobMode": true,
      "LobMaxSize": 32
    },
    "FullLoadSettings": {
      "TargetTablePrepMode": "DROP_AND_CREATE",
      "CreatePkAfterFullLoad": false,
      "StopTaskCachedChangesApplied": false,
      "StopTaskCachedChangesNotApplied": false,
      "MaxFullLoadSubTasks": 8,
      "TransactionConsistencyTimeout": 600,
      "CommitRate": 10000
    },
    "Logging": {
      "EnableLogging": true,
      "LogComponents": [
        {
          "Id": "SOURCE_UNLOAD",
          "Severity": "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id": "TARGET_LOAD",
          "Severity": "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id": "SOURCE_CAPTURE",
          "Severity": "LOGGER_SEVERITY_DEFAULT"
        },
        {
          "Id": "TARGET_APPLY",
          "Severity": "LOGGER_SEVERITY_DEFAULT"
        }
      ]
    },
    "ControlTablesSettings": {
      "ControlSchema": "",
      "HistoryTimeslotInMinutes": 5,
      "HistoryTableEnabled": true,
      "SuspendedTablesTableEnabled": true,
      "StatusTableEnabled": true
    },
    "ChangeProcessingDdlHandlingPolicy": {
      "HandleSourceTableDropped": true,
      "HandleSourceTableTruncated": true,
      "HandleSourceTableAltered": true
    },
    "ErrorBehavior": {
      "DataErrorPolicy": "LOG_ERROR",
      "EventErrorPolicy": "IGNORE",
      "DataTruncationErrorPolicy": "LOG_ERROR",
      "DataErrorEscalationPolicy": "SUSPEND_TABLE",
      "DataErrorEscalationCount": 50,
      "TableErrorPolicy": "SUSPEND_TABLE",
      "TableErrorEscalationPolicy": "STOP_TASK",
      "TableErrorEscalationCount": 50,
      "RecoverableErrorCount": -1,
      "RecoverableErrorInterval": 5,
      "RecoverableErrorThrottling": true,
      "RecoverableErrorThrottlingMax": 1800,
      "ApplyErrorDeletePolicy": "IGNORE_RECORD",
      "ApplyErrorInsertPolicy": "LOG_ERROR",
      "ApplyErrorUpdatePolicy": "LOG_ERROR",
      "ApplyErrorEscalationPolicy": "LOG_ERROR",
      "ApplyErrorEscalationCount": 0,
      "FullLoadIgnoreConflicts": true
    }
  })

  tags = merge(var.tags, {
    Name = var.replication_task_id
  })

  # Ensure endpoints are created and tested before task
  depends_on = [
    aws_dms_endpoint.source,
    aws_dms_endpoint.target
  ]
}

# CloudWatch Log Group for DMS
resource "aws_cloudwatch_log_group" "dms_logs" {
  name              = "/aws/dms/${var.replication_task_id}"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "dms-replication-logs"
  })
}
