import json
import boto3
import os
import time
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Any

# Initialize AWS clients
rds = boto3.client('rds')
dms = boto3.client('dms')
sns = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')
s3 = boto3.client('s3')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    RPO Enhancement Orchestrator
    Creates hourly backups and monitors replication lag to achieve 1-hour RPO
    
    Target RPO: 1 hour
    """
    
    print(f"📊 RPO Enhancement Event: {json.dumps(event, indent=2)}")
    
    # Environment variables
    environment = os.environ.get('ENVIRONMENT', 'development')
    primary_region = os.environ.get('PRIMARY_REGION', 'us-east-1')
    standby_region = os.environ.get('STANDBY_REGION', 'us-west-2')
    primary_rds_id = os.environ.get('PRIMARY_RDS_IDENTIFIER')
    standby_rds_id = os.environ.get('STANDBY_RDS_IDENTIFIER')
    retention_hours = int(os.environ.get('BACKUP_RETENTION_HOURS', '168'))
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    backup_bucket = os.environ.get('BACKUP_BUCKET_NAME')
    dms_task_arn = os.environ.get('DMS_TASK_ARN', '')
    
    try:
        # Parse event
        action = event.get('action', 'create_hourly_backup')
        source = event.get('source', 'manual')
        
        start_time = datetime.now(timezone.utc)
        
        print(f"🕐 Starting RPO enhancement process...")
        print(f"   Environment: {environment}")
        print(f"   Action: {action}")
        print(f"   Source: {source}")
        print(f"   Start Time: {start_time.isoformat()}")
        
        if action == 'create_hourly_backup':
            result = create_hourly_backups(
                primary_rds_id, standby_rds_id, 
                primary_region, standby_region,
                backup_bucket, sns_topic_arn
            )
            
        elif action == 'cleanup_old_backups':
            result = cleanup_old_backups(
                primary_rds_id, standby_rds_id,
                primary_region, standby_region,
                retention_hours, sns_topic_arn
            )
            
        elif action == 'monitor_replication_lag':
            result = monitor_replication_lag(
                dms_task_arn, sns_topic_arn
            )
            
        else:
            result = {
                'success': False,
                'error': f'Unknown action: {action}'
            }
        
        # Calculate current RPO and send metrics
        current_rpo = calculate_current_rpo(primary_rds_id, dms_task_arn)
        put_custom_metric("CurrentRPO", current_rpo)
        
        total_time = (datetime.now(timezone.utc) - start_time).total_seconds()
        
        if result['success']:
            success_msg = f"✅ RPO ENHANCEMENT COMPLETED\n"
            success_msg += f"Action: {action}\n"
            success_msg += f"Time: {total_time:.1f} seconds\n"
            success_msg += f"Current RPO: {current_rpo:.1f} minutes\n"
            success_msg += f"Details: {result.get('message', 'Success')}"
            
            if current_rpo <= 60:  # Within 1-hour target
                print("SUCCESS " + success_msg)
                put_custom_metric("HourlyBackupSuccess", 1)
            else:
                print("WARNING RPO exceeds 1-hour target")
                send_notification(sns_topic_arn, "⚠️ RPO WARNING", 
                                f"Current RPO: {current_rpo:.1f} minutes exceeds 60-minute target", "WARNING")
            
            return create_response(200, success_msg, start_time, {
                'current_rpo_minutes': current_rpo,
                'action_details': result
            })
        else:
            error_msg = f"❌ RPO ENHANCEMENT FAILED\n"
            error_msg += f"Action: {action}\n"
            error_msg += f"Error: {result.get('error', 'Unknown error')}"
            
            print("ERROR " + error_msg)
            send_notification(sns_topic_arn, "❌ RPO FAILED", error_msg, "CRITICAL")
            put_custom_metric("HourlyBackupFailure", 1)
            
            return create_response(500, error_msg, start_time)
            
    except Exception as e:
        error_msg = f"❌ RPO ENHANCEMENT ERROR: {str(e)}"
        print("ERROR " + error_msg)
        
        total_time = (datetime.now(timezone.utc) - start_time).total_seconds()
        send_notification(sns_topic_arn, "❌ RPO ERROR", error_msg, "CRITICAL")
        put_custom_metric("HourlyBackupFailure", 1)
        
        return create_response(500, error_msg, start_time)

def create_hourly_backups(primary_rds_id: str, standby_rds_id: str,
                         primary_region: str, standby_region: str,
                         backup_bucket: str, sns_topic_arn: str) -> Dict[str, Any]:
    """Create hourly snapshots of both primary and standby RDS instances"""
    
    results = {
        'success': True,
        'primary_snapshot': None,
        'standby_snapshot': None,
        'errors': []
    }
    
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d-%H-%M-%S')
    
    try:
        # Create primary region snapshot
        print(f"📸 Creating primary snapshot: {primary_rds_id}")
        primary_snapshot_id = f"{primary_rds_id}-hourly-{timestamp}"
        
        try:
            primary_response = rds.create_db_snapshot(
                DBSnapshotIdentifier=primary_snapshot_id,
                DBInstanceIdentifier=primary_rds_id,
                Tags=[
                    {'Key': 'BackupType', 'Value': 'Hourly'},
                    {'Key': 'CreatedBy', 'Value': 'RPO-Enhancement'},
                    {'Key': 'RPOTarget', 'Value': '1-hour'},
                    {'Key': 'Timestamp', 'Value': timestamp}
                ]
            )
            
            results['primary_snapshot'] = {
                'snapshot_id': primary_snapshot_id,
                'status': 'creating',
                'region': primary_region
            }
            
            print(f"✅ Primary snapshot created: {primary_snapshot_id}")
            
        except Exception as e:
            error_msg = f"Failed to create primary snapshot: {str(e)}"
            results['errors'].append(error_msg)
            print(f"❌ {error_msg}")
        
        # Create standby region snapshot
        if standby_rds_id:
            print(f"📸 Creating standby snapshot: {standby_rds_id}")
            standby_snapshot_id = f"{standby_rds_id}-hourly-{timestamp}"
            
            try:
                # Create RDS client for standby region
                rds_standby = boto3.client('rds', region_name=standby_region)
                
                standby_response = rds_standby.create_db_snapshot(
                    DBSnapshotIdentifier=standby_snapshot_id,
                    DBInstanceIdentifier=standby_rds_id,
                    Tags=[
                        {'Key': 'BackupType', 'Value': 'Hourly'},
                        {'Key': 'CreatedBy', 'Value': 'RPO-Enhancement'},
                        {'Key': 'RPOTarget', 'Value': '1-hour'},
                        {'Key': 'Timestamp', 'Value': timestamp}
                    ]
                )
                
                results['standby_snapshot'] = {
                    'snapshot_id': standby_snapshot_id,
                    'status': 'creating',
                    'region': standby_region
                }
                
                print(f"✅ Standby snapshot created: {standby_snapshot_id}")
                
            except Exception as e:
                error_msg = f"Failed to create standby snapshot: {str(e)}"
                results['errors'].append(error_msg)
                print(f"❌ {error_msg}")
        
        # Store backup metadata in S3
        if backup_bucket:
            try:
                backup_metadata = {
                    'timestamp': timestamp,
                    'primary_snapshot': results.get('primary_snapshot'),
                    'standby_snapshot': results.get('standby_snapshot'),
                    'rpo_target_minutes': 60,
                    'backup_type': 'hourly_automated'
                }
                
                s3.put_object(
                    Bucket=backup_bucket,
                    Key=f"backups/{timestamp}/metadata.json",
                    Body=json.dumps(backup_metadata, indent=2),
                    ContentType='application/json'
                )
                
                print(f"📝 Backup metadata stored in S3")
                
            except Exception as e:
                error_msg = f"Failed to store backup metadata: {str(e)}"
                results['errors'].append(error_msg)
                print(f"❌ {error_msg}")
        
        # Determine overall success
        if len(results['errors']) > 0:
            results['success'] = len(results['errors']) < 2  # Partial success if only one failed
            results['message'] = f"Completed with {len(results['errors'])} errors"
        else:
            results['message'] = "All hourly backups created successfully"
        
        return results
        
    except Exception as e:
        return {
            'success': False,
            'error': f"Hourly backup creation failed: {str(e)}"
        }

def cleanup_old_backups(primary_rds_id: str, standby_rds_id: str,
                       primary_region: str, standby_region: str,
                       retention_hours: int, sns_topic_arn: str) -> Dict[str, Any]:
    """Clean up old hourly snapshots beyond retention period"""
    
    results = {
        'success': True,
        'deleted_snapshots': [],
        'errors': []
    }
    
    cutoff_time = datetime.now(timezone.utc) - timedelta(hours=retention_hours)
    
    try:
        # Clean up primary region snapshots
        print(f"🧹 Cleaning up primary region snapshots older than {retention_hours} hours")
        primary_deleted = cleanup_snapshots_in_region(
            primary_rds_id, primary_region, cutoff_time, 'primary'
        )
        results['deleted_snapshots'].extend(primary_deleted)
        
        # Clean up standby region snapshots
        if standby_rds_id:
            print(f"🧹 Cleaning up standby region snapshots older than {retention_hours} hours")
            standby_deleted = cleanup_snapshots_in_region(
                standby_rds_id, standby_region, cutoff_time, 'standby'
            )
            results['deleted_snapshots'].extend(standby_deleted)
        
        results['message'] = f"Cleaned up {len(results['deleted_snapshots'])} old snapshots"
        print(f"✅ {results['message']}")
        
        return results
        
    except Exception as e:
        return {
            'success': False,
            'error': f"Backup cleanup failed: {str(e)}"
        }

def cleanup_snapshots_in_region(rds_id: str, region: str, cutoff_time: datetime, region_type: str) -> List[Dict]:
    """Clean up snapshots in a specific region"""
    
    deleted_snapshots = []
    
    try:
        rds_client = boto3.client('rds', region_name=region)
        
        # List all snapshots for this RDS instance
        response = rds_client.describe_db_snapshots(
            DBInstanceIdentifier=rds_id,
            SnapshotType='manual'
        )
        
        for snapshot in response['DBSnapshots']:
            snapshot_id = snapshot['DBSnapshotIdentifier']
            
            # Only clean up hourly snapshots created by our system
            if 'hourly' in snapshot_id and snapshot.get('SnapshotCreateTime'):
                snapshot_time = snapshot['SnapshotCreateTime']
                
                # Make timezone-aware if needed
                if snapshot_time.tzinfo is None:
                    snapshot_time = snapshot_time.replace(tzinfo=timezone.utc)
                
                if snapshot_time < cutoff_time:
                    try:
                        rds_client.delete_db_snapshot(
                            DBSnapshotIdentifier=snapshot_id
                        )
                        
                        deleted_snapshots.append({
                            'snapshot_id': snapshot_id,
                            'region': region,
                            'region_type': region_type,
                            'created_time': snapshot_time.isoformat()
                        })
                        
                        print(f"🗑️ Deleted old snapshot: {snapshot_id}")
                        
                    except Exception as e:
                        print(f"❌ Failed to delete snapshot {snapshot_id}: {str(e)}")
        
        return deleted_snapshots
        
    except Exception as e:
        print(f"❌ Error cleaning up snapshots in {region}: {str(e)}")
        return []

def monitor_replication_lag(dms_task_arn: str, sns_topic_arn: str) -> Dict[str, Any]:
    """Monitor DMS replication lag to ensure it's within RPO target"""
    
    if not dms_task_arn:
        return {
            'success': True,
            'message': 'No DMS task configured, skipping lag monitoring'
        }
    
    try:
        # Get DMS task statistics
        response = dms.describe_replication_tasks(
            Filters=[
                {
                    'Name': 'replication-task-arn',
                    'Values': [dms_task_arn]
                }
            ]
        )
        
        if not response['ReplicationTasks']:
            return {
                'success': False,
                'error': f'DMS task not found: {dms_task_arn}'
            }
        
        task = response['ReplicationTasks'][0]
        task_status = task['Status']
        
        # Get CloudWatch metrics for replication lag
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=15)
        
        cw_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/DMS',
            MetricName='CDCLatencyTarget',
            Dimensions=[
                {
                    'Name': 'ReplicationTaskArn',
                    'Value': dms_task_arn
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average', 'Maximum']
        )
        
        if cw_response['Datapoints']:
            latest_datapoint = sorted(cw_response['Datapoints'], 
                                    key=lambda x: x['Timestamp'])[-1]
            avg_lag_seconds = latest_datapoint['Average']
            max_lag_seconds = latest_datapoint['Maximum']
            
            avg_lag_minutes = avg_lag_seconds / 60
            max_lag_minutes = max_lag_seconds / 60
            
            # Check if lag exceeds RPO target (60 minutes)
            if max_lag_minutes > 60:
                warning_msg = f"⚠️ DMS REPLICATION LAG WARNING\n"
                warning_msg += f"Current lag: {max_lag_minutes:.1f} minutes\n"
                warning_msg += f"RPO target: 60 minutes\n"
                warning_msg += f"Task status: {task_status}"
                
                send_notification(sns_topic_arn, "⚠️ REPLICATION LAG", warning_msg, "WARNING")
            
            return {
                'success': True,
                'task_status': task_status,
                'avg_lag_minutes': avg_lag_minutes,
                'max_lag_minutes': max_lag_minutes,
                'within_rpo_target': max_lag_minutes <= 60
            }
        else:
            return {
                'success': True,
                'message': 'No recent replication lag data available',
                'task_status': task_status
            }
            
    except Exception as e:
        return {
            'success': False,
            'error': f"Failed to monitor replication lag: {str(e)}"
        }

def calculate_current_rpo(primary_rds_id: str, dms_task_arn: str) -> float:
    """Calculate current RPO based on latest backup and replication lag"""
    
    try:
        # Get latest snapshot time
        response = rds.describe_db_snapshots(
            DBInstanceIdentifier=primary_rds_id,
            SnapshotType='manual',
            MaxRecords=1
        )
        
        if response['DBSnapshots']:
            latest_snapshot = response['DBSnapshots'][0]
            snapshot_time = latest_snapshot['SnapshotCreateTime']
            
            # Make timezone-aware if needed
            if snapshot_time.tzinfo is None:
                snapshot_time = snapshot_time.replace(tzinfo=timezone.utc)
            
            # Calculate time since last backup
            now = datetime.now(timezone.utc)
            time_since_backup = (now - snapshot_time).total_seconds() / 60  # minutes
            
            # Factor in DMS replication lag if available
            if dms_task_arn:
                replication_result = monitor_replication_lag(dms_task_arn, None)
                if replication_result.get('success') and 'max_lag_minutes' in replication_result:
                    dms_lag = replication_result['max_lag_minutes']
                    # RPO is the maximum of backup age and replication lag
                    current_rpo = max(time_since_backup, dms_lag)
                else:
                    current_rpo = time_since_backup
            else:
                current_rpo = time_since_backup
            
            return current_rpo
        else:
            # No snapshots found, RPO is potentially very high
            return 1440  # 24 hours
            
    except Exception as e:
        print(f"❌ Error calculating RPO: {str(e)}")
        return 999  # Unknown RPO

def send_notification(topic_arn: str, subject: str, message: str, severity: str = "INFO"):
    """Send SNS notification"""
    try:
        if not topic_arn:
            print(f"📧 No SNS topic configured, would send: {subject}")
            return
            
        sns.publish(
            TopicArn=topic_arn,
            Subject=f"[{severity}] {subject}",
            Message=message
        )
        print(f"📧 Notification sent: {subject}")
    except Exception as e:
        print(f"❌ Failed to send notification: {str(e)}")

def put_custom_metric(metric_name: str, value: float):
    """Send custom CloudWatch metric"""
    try:
        dimensions = [
            {
                'Name': 'Environment',
                'Value': os.environ.get('ENVIRONMENT', 'development')
            }
        ]
        
        cloudwatch.put_metric_data(
            Namespace='Project3/RPO',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': 'Count' if 'Success' in metric_name or 'Failure' in metric_name else 'None',
                    'Dimensions': dimensions
                }
            ]
        )
        
        print(f"📊 Metric sent: {metric_name} = {value}")
    except Exception as e:
        print(f"❌ Failed to send metric: {str(e)}")

def create_response(status_code: int, message: str, start_time: datetime, 
                   additional_data: Dict[str, Any] = None) -> Dict[str, Any]:
    """Create standardized response"""
    end_time = datetime.now(timezone.utc)
    duration = (end_time - start_time).total_seconds()
    
    response = {
        'statusCode': status_code,
        'message': message,
        'timestamp': end_time.isoformat(),
        'duration_seconds': duration,
        'environment': os.environ.get('ENVIRONMENT', 'development')
    }
    
    if additional_data:
        response.update(additional_data)
    
    return response
