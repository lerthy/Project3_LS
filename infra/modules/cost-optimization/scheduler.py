import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """
    Resource scheduler for non-production environments
    Stops/starts RDS instances and manages Lambda provisioned concurrency
    """
    
    print(f"Scheduler event: {json.dumps(event)}")
    
    # Initialize AWS clients
    rds = boto3.client('rds')
    lambda_client = boto3.client('lambda')
    sns = boto3.client('sns')
    
    # Get configuration from environment variables
    environment = os.environ.get('ENVIRONMENT', 'development')
    rds_identifier = os.environ.get('RDS_IDENTIFIER', 'contact-db')
    lambda_function = os.environ.get('LAMBDA_FUNCTION', 'contact-form')
    
    # Parse the event
    action = event.get('action', 'unknown')
    
    results = []
    errors = []
    
    try:
        if action == 'stop':
            print(f"🛑 Stopping resources for {environment} environment...")
            
            # Stop RDS instance
            try:
                # Check if RDS is running
                response = rds.describe_db_instances(DBInstanceIdentifier=rds_identifier)
                db_status = response['DBInstances'][0]['DBInstanceStatus']
                
                if db_status == 'available':
                    print(f"Stopping RDS instance: {rds_identifier}")
                    rds.stop_db_instance(DBInstanceIdentifier=rds_identifier)
                    results.append(f"✅ RDS {rds_identifier} stop initiated")
                else:
                    results.append(f"⏭️ RDS {rds_identifier} already in state: {db_status}")
                    
            except Exception as e:
                error_msg = f"❌ Failed to stop RDS {rds_identifier}: {str(e)}"
                print(error_msg)
                errors.append(error_msg)
            
            # Remove Lambda provisioned concurrency
            try:
                # Check if provisioned concurrency exists
                try:
                    lambda_client.get_provisioned_concurrency_config(
                        FunctionName=lambda_function,
                        Qualifier='$LATEST'
                    )
                    
                    # Remove it
                    lambda_client.delete_provisioned_concurrency_config(
                        FunctionName=lambda_function,
                        Qualifier='$LATEST'
                    )
                    results.append(f"✅ Lambda {lambda_function} provisioned concurrency removed")
                    
                except lambda_client.exceptions.ProvisionedConcurrencyConfigNotFoundException:
                    results.append(f"⏭️ Lambda {lambda_function} provisioned concurrency already removed")
                    
            except Exception as e:
                error_msg = f"❌ Failed to remove Lambda provisioned concurrency: {str(e)}"
                print(error_msg)
                errors.append(error_msg)
        
        elif action == 'start':
            print(f"🚀 Starting resources for {environment} environment...")
            
            # Start RDS instance
            try:
                # Check if RDS is stopped
                response = rds.describe_db_instances(DBInstanceIdentifier=rds_identifier)
                db_status = response['DBInstances'][0]['DBInstanceStatus']
                
                if db_status == 'stopped':
                    print(f"Starting RDS instance: {rds_identifier}")
                    rds.start_db_instance(DBInstanceIdentifier=rds_identifier)
                    results.append(f"✅ RDS {rds_identifier} start initiated")
                else:
                    results.append(f"⏭️ RDS {rds_identifier} already in state: {db_status}")
                    
            except Exception as e:
                error_msg = f"❌ Failed to start RDS {rds_identifier}: {str(e)}"
                print(error_msg)
                errors.append(error_msg)
            
            # Add Lambda provisioned concurrency (only for development with minimal cost)
            try:
                lambda_client.put_provisioned_concurrency_config(
                    FunctionName=lambda_function,
                    Qualifier='$LATEST',
                    ProvisionedConcurrencyConfig=1  # Minimal provisioned concurrency
                )
                results.append(f"✅ Lambda {lambda_function} provisioned concurrency set to 1")
                
            except Exception as e:
                error_msg = f"❌ Failed to set Lambda provisioned concurrency: {str(e)}"
                print(error_msg)
                errors.append(error_msg)
        
        else:
            error_msg = f"❌ Unknown action: {action}"
            print(error_msg)
            errors.append(error_msg)
    
    except Exception as e:
        error_msg = f"❌ Unexpected error: {str(e)}"
        print(error_msg)
        errors.append(error_msg)
    
    # Prepare summary
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    summary = f"""
📊 Resource Scheduler Report - {timestamp}
🏷️ Environment: {environment}
🎯 Action: {action.upper()}

✅ Successful Operations:
{chr(10).join(results) if results else "None"}

❌ Errors:
{chr(10).join(errors) if errors else "None"}

💰 Estimated Cost Impact:
- RDS stopped/started: ~$2-10/day saved during off-hours
- Lambda provisioned concurrency: ~$1-3/day saved when removed
"""
    
    print(summary)
    
    # Send notification if there are errors or if it's a significant action
    if errors or len(results) > 0:
        try:
            # Note: In production, you'd get this from environment or parameter
            # For now, we'll skip the SNS notification to avoid dependency issues
            print("📧 Notification would be sent here in production")
            
        except Exception as e:
            print(f"⚠️ Failed to send notification: {str(e)}")
    
    # Return response
    return {
        'statusCode': 200 if not errors else 207,  # 207 = Multi-Status (partial success)
        'body': json.dumps({
            'action': action,
            'environment': environment,
            'timestamp': timestamp,
            'results': results,
            'errors': errors,
            'summary': summary
        })
    }
