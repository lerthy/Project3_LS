#!/usr/bin/env python3
"""
Infrastructure Drift Detection Lambda Function

This function performs daily drift detection by:
1. Analyzing Terraform state file
2. Comparing with actual AWS resources
3. Detecting configuration drift
4. Sending notifications for drift events
5. Publishing metrics to CloudWatch
"""

import json
import boto3
import os
from datetime import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Main Lambda handler for infrastructure drift detection
    """
    try:
        logger.info("Starting infrastructure drift detection")
        
        # Get environment variables
        state_bucket = os.environ['TERRAFORM_STATE_BUCKET']
        state_key = os.environ['TERRAFORM_STATE_KEY']
        sns_topic = os.environ['SNS_TOPIC_ARN']
        environment = os.environ['ENVIRONMENT']
        
        # Initialize AWS clients
        s3_client = boto3.client('s3')
        sns_client = boto3.client('sns')
        cloudwatch_client = boto3.client('cloudwatch')
        
        # Analyze Terraform state
        drift_results = analyze_terraform_state(s3_client, state_bucket, state_key)
        
        # Check for drift
        drift_detected = len(drift_results['drifted_resources']) > 0
        drift_count = len(drift_results['drifted_resources'])
        
        # Publish metrics
        publish_drift_metrics(cloudwatch_client, environment, drift_count, drift_detected)
        
        if drift_detected:
            # Send notification
            send_drift_notification(sns_client, sns_topic, drift_results, environment)
            logger.warning(f"Infrastructure drift detected: {drift_count} resources")
        else:
            logger.info("No infrastructure drift detected")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'drift_detected': drift_detected,
                'drift_count': drift_count,
                'timestamp': datetime.utcnow().isoformat(),
                'drifted_resources': drift_results['drifted_resources']
            })
        }
        
    except Exception as e:
        logger.error(f"Drift detection failed: {str(e)}")
        
        # Send error notification
        try:
            send_error_notification(sns_client, sns_topic, str(e), environment)
        except:
            pass
            
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def analyze_terraform_state(s3_client, bucket, key):
    """
    Analyze Terraform state file for potential drift
    """
    try:
        # Download state file
        response = s3_client.get_object(Bucket=bucket, Key=key)
        state_data = json.loads(response['Body'].read())
        
        drift_results = {
            'drifted_resources': [],
            'total_resources': 0,
            'analysis_timestamp': datetime.utcnow().isoformat()
        }
        
        # Analyze resources in state
        if 'resources' in state_data:
            drift_results['total_resources'] = len(state_data['resources'])
            
            for resource in state_data['resources']:
                # Simulate drift detection logic
                # In a real implementation, you would compare state with actual AWS resources
                resource_type = resource.get('type', 'unknown')
                resource_name = resource.get('name', 'unknown')
                
                # Basic drift detection - check for common drift scenarios
                if check_resource_drift(resource):
                    drift_results['drifted_resources'].append({
                        'type': resource_type,
                        'name': resource_name,
                        'drift_type': 'configuration_change',
                        'details': 'Resource configuration may have changed outside of Terraform'
                    })
        
        logger.info(f"Analyzed {drift_results['total_resources']} resources")
        return drift_results
        
    except Exception as e:
        logger.error(f"Failed to analyze Terraform state: {str(e)}")
        raise

def check_resource_drift(resource):
    """
    Check if a specific resource has drifted
    This is a simplified implementation - real drift detection would be more comprehensive
    """
    # For demonstration, we'll simulate occasional drift detection
    # In production, this would compare Terraform state with actual AWS resource state
    
    import hashlib
    import random
    
    # Create a deterministic "drift" based on resource hash
    # This ensures consistent results for the same resources
    resource_hash = hashlib.md5(str(resource).encode()).hexdigest()
    seed = int(resource_hash[:8], 16)
    random.seed(seed)
    
    # Simulate 5% chance of drift for demonstration
    return random.random() < 0.05

def publish_drift_metrics(cloudwatch_client, environment, drift_count, drift_detected):
    """
    Publish drift detection metrics to CloudWatch
    """
    try:
        # Publish drift count metric
        cloudwatch_client.put_metric_data(
            Namespace='Custom/InfrastructureDrift',
            MetricData=[
                {
                    'MetricName': 'DriftCount',
                    'Dimensions': [
                        {
                            'Name': 'Environment',
                            'Value': environment
                        }
                    ],
                    'Value': drift_count,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'DriftDetected',
                    'Dimensions': [
                        {
                            'Name': 'Environment',
                            'Value': environment
                        }
                    ],
                    'Value': 1 if drift_detected else 0,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        logger.info("Published drift metrics to CloudWatch")
        
    except Exception as e:
        logger.error(f"Failed to publish metrics: {str(e)}")

def send_drift_notification(sns_client, topic_arn, drift_results, environment):
    """
    Send drift notification via SNS
    """
    try:
        drift_count = len(drift_results['drifted_resources'])
        
        subject = f"🚨 Infrastructure Drift Detected - {environment.upper()}"
        
        message = f"""
Infrastructure Drift Detection Alert

Environment: {environment}
Detection Time: {drift_results['analysis_timestamp']}
Total Resources Analyzed: {drift_results['total_resources']}
Drifted Resources Found: {drift_count}

Drifted Resources:
"""
        
        for resource in drift_results['drifted_resources']:
            message += f"""
- Type: {resource['type']}
  Name: {resource['name']}
  Drift Type: {resource['drift_type']}
  Details: {resource['details']}
"""
        
        message += f"""

Recommendations:
1. Review the drifted resources listed above
2. Update Terraform configuration to match current state, or
3. Run 'terraform apply' to restore desired state
4. Consider using resource import if resources were created outside Terraform

Next Steps:
- Login to AWS Console to verify resource configurations
- Run 'terraform plan' to see proposed changes
- Apply changes using your CI/CD pipeline

This is an automated alert from the Infrastructure Drift Detection system.
"""
        
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info("Sent drift notification")
        
    except Exception as e:
        logger.error(f"Failed to send drift notification: {str(e)}")

def send_error_notification(sns_client, topic_arn, error_message, environment):
    """
    Send error notification if drift detection fails
    """
    try:
        subject = f"❌ Drift Detection Failed - {environment.upper()}"
        
        message = f"""
Infrastructure Drift Detection Error

Environment: {environment}
Error Time: {datetime.utcnow().isoformat()}
Error Message: {error_message}

The automated drift detection process encountered an error and could not complete successfully.

Please investigate the issue and ensure:
1. Terraform state file is accessible
2. Lambda function has required permissions
3. AWS services are functioning normally

This may indicate a problem with the monitoring system that needs immediate attention.
"""
        
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info("Sent error notification")
        
    except Exception as e:
        logger.error(f"Failed to send error notification: {str(e)}")

if __name__ == "__main__":
    # For local testing
    test_event = {}
    test_context = type('Context', (), {
        'function_name': 'test-drift-detection',
        'aws_request_id': 'test-request-id'
    })()
    
    # Set test environment variables
    os.environ['TERRAFORM_STATE_BUCKET'] = 'test-bucket'
    os.environ['TERRAFORM_STATE_KEY'] = 'test-key'
    os.environ['SNS_TOPIC_ARN'] = 'arn:aws:sns:us-east-1:123456789012:test-topic'
    os.environ['ENVIRONMENT'] = 'development'
    
    result = handler(test_event, test_context)
    print(json.dumps(result, indent=2))
