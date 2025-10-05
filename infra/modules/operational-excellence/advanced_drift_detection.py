#!/usr/bin/env python3
"""
Advanced Infrastructure Drift Detection Lambda Function
P2 Reliability Enhancement

This enhanced function provides:
1. Real-time drift detection
2. Resource-specific analysis
3. Automated remediation suggestions
4. CI/CD pipeline integration
5. State reconciliation recommendations
"""

import json
import boto3
import os
from datetime import datetime, timedelta
import logging
import hashlib
from typing import Dict, List, Any, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients (initialized globally for reuse)
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
cloudwatch_client = boto3.client('cloudwatch')
ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
apigateway_client = boto3.client('apigateway')
lambda_client = boto3.client('lambda')
cloudfront_client = boto3.client('cloudfront')
route53_client = boto3.client('route53')

class DriftAnalyzer:
    """Advanced drift detection and analysis"""
    
    def __init__(self, environment: str, region: str):
        self.environment = environment
        self.region = region
        self.drift_results = {
            'critical_drift': [],
            'major_drift': [],
            'minor_drift': [],
            'remediation_suggestions': [],
            'state_reconciliation': [],
            'ci_cd_integration': {}
        }
    
    def analyze_vpc_drift(self, terraform_vpcs: List[Dict]) -> None:
        """Analyze VPC configuration drift"""
        try:
            # Get actual VPCs
            actual_vpcs = ec2_client.describe_vpcs()['Vpcs']
            
            for tf_vpc in terraform_vpcs:
                vpc_id = tf_vpc.get('id')
                if not vpc_id:
                    continue
                    
                # Find matching actual VPC
                actual_vpc = next((v for v in actual_vpcs if v['VpcId'] == vpc_id), None)
                if not actual_vpc:
                    self.drift_results['critical_drift'].append({
                        'resource_type': 'VPC',
                        'resource_id': vpc_id,
                        'drift_type': 'RESOURCE_DELETED',
                        'severity': 'CRITICAL',
                        'details': f'VPC {vpc_id} exists in Terraform state but not in AWS'
                    })
                    continue
                
                # Check CIDR block drift
                tf_cidr = tf_vpc.get('cidr_block', '')
                actual_cidr = actual_vpc.get('CidrBlock', '')
                if tf_cidr != actual_cidr:
                    self.drift_results['major_drift'].append({
                        'resource_type': 'VPC',
                        'resource_id': vpc_id,
                        'drift_type': 'CIDR_MISMATCH',
                        'severity': 'MAJOR',
                        'terraform_value': tf_cidr,
                        'actual_value': actual_cidr,
                        'remediation': f'Update Terraform VPC CIDR to match actual: {actual_cidr}'
                    })
                
                # Check tags drift
                self._check_tags_drift('VPC', vpc_id, tf_vpc.get('tags', {}), actual_vpc.get('Tags', []))
                
        except Exception as e:
            logger.error(f"VPC drift analysis failed: {str(e)}")
    
    def analyze_rds_drift(self, terraform_rds: List[Dict]) -> None:
        """Analyze RDS configuration drift"""
        try:
            # Get actual RDS instances
            actual_rds = rds_client.describe_db_instances()['DBInstances']
            
            for tf_db in terraform_rds:
                db_identifier = tf_db.get('identifier')
                if not db_identifier:
                    continue
                    
                # Find matching actual RDS
                actual_db = next((db for db in actual_rds if db['DBInstanceIdentifier'] == db_identifier), None)
                if not actual_db:
                    self.drift_results['critical_drift'].append({
                        'resource_type': 'RDS',
                        'resource_id': db_identifier,
                        'drift_type': 'RESOURCE_DELETED',
                        'severity': 'CRITICAL',
                        'details': f'RDS instance {db_identifier} exists in Terraform state but not in AWS'
                    })
                    continue
                
                # Check instance class drift
                tf_class = tf_db.get('instance_class', '')
                actual_class = actual_db.get('DBInstanceClass', '')
                if tf_class != actual_class:
                    self.drift_results['major_drift'].append({
                        'resource_type': 'RDS',
                        'resource_id': db_identifier,
                        'drift_type': 'INSTANCE_CLASS_MISMATCH',
                        'severity': 'MAJOR',
                        'terraform_value': tf_class,
                        'actual_value': actual_class,
                        'cost_impact': self._calculate_rds_cost_impact(tf_class, actual_class),
                        'remediation': f'Update Terraform RDS instance class to match actual: {actual_class}'
                    })
                
                # Check backup retention drift
                tf_backup = tf_db.get('backup_retention_period', 0)
                actual_backup = actual_db.get('BackupRetentionPeriod', 0)
                if tf_backup != actual_backup:
                    self.drift_results['minor_drift'].append({
                        'resource_type': 'RDS',
                        'resource_id': db_identifier,
                        'drift_type': 'BACKUP_RETENTION_MISMATCH',
                        'severity': 'MINOR',
                        'terraform_value': tf_backup,
                        'actual_value': actual_backup,
                        'compliance_impact': 'May affect backup compliance requirements'
                    })
                    
        except Exception as e:
            logger.error(f"RDS drift analysis failed: {str(e)}")
    
    def analyze_lambda_drift(self, terraform_lambdas: List[Dict]) -> None:
        """Analyze Lambda function configuration drift"""
        try:
            # Get actual Lambda functions
            actual_lambdas = lambda_client.list_functions()['Functions']
            
            for tf_lambda in terraform_lambdas:
                function_name = tf_lambda.get('function_name')
                if not function_name:
                    continue
                    
                # Find matching actual Lambda
                actual_lambda = next((f for f in actual_lambdas if f['FunctionName'] == function_name), None)
                if not actual_lambda:
                    self.drift_results['critical_drift'].append({
                        'resource_type': 'Lambda',
                        'resource_id': function_name,
                        'drift_type': 'RESOURCE_DELETED',
                        'severity': 'CRITICAL',
                        'details': f'Lambda function {function_name} exists in Terraform state but not in AWS'
                    })
                    continue
                
                # Check runtime drift
                tf_runtime = tf_lambda.get('runtime', '')
                actual_runtime = actual_lambda.get('Runtime', '')
                if tf_runtime != actual_runtime:
                    self.drift_results['major_drift'].append({
                        'resource_type': 'Lambda',
                        'resource_id': function_name,
                        'drift_type': 'RUNTIME_MISMATCH',
                        'severity': 'MAJOR',
                        'terraform_value': tf_runtime,
                        'actual_value': actual_runtime,
                        'security_impact': 'Runtime version may have security implications',
                        'remediation': f'Update Terraform Lambda runtime to match actual: {actual_runtime}'
                    })
                
                # Check memory configuration drift
                tf_memory = tf_lambda.get('memory_size', 128)
                actual_memory = actual_lambda.get('MemorySize', 128)
                if tf_memory != actual_memory:
                    self.drift_results['minor_drift'].append({
                        'resource_type': 'Lambda',
                        'resource_id': function_name,
                        'drift_type': 'MEMORY_MISMATCH',
                        'severity': 'MINOR',
                        'terraform_value': tf_memory,
                        'actual_value': actual_memory,
                        'cost_impact': self._calculate_lambda_cost_impact(tf_memory, actual_memory)
                    })
                    
        except Exception as e:
            logger.error(f"Lambda drift analysis failed: {str(e)}")
    
    def _check_tags_drift(self, resource_type: str, resource_id: str, tf_tags: Dict, actual_tags: List[Dict]) -> None:
        """Check for tag configuration drift"""
        # Convert AWS tags format to dict
        actual_tags_dict = {tag.get('Key', ''): tag.get('Value', '') for tag in actual_tags}
        
        # Check for missing or different tags
        for tf_key, tf_value in tf_tags.items():
            actual_value = actual_tags_dict.get(tf_key)
            if actual_value != tf_value:
                self.drift_results['minor_drift'].append({
                    'resource_type': resource_type,
                    'resource_id': resource_id,
                    'drift_type': 'TAG_MISMATCH',
                    'severity': 'MINOR',
                    'tag_key': tf_key,
                    'terraform_value': tf_value,
                    'actual_value': actual_value or 'MISSING',
                    'compliance_impact': 'May affect resource governance and cost allocation'
                })
    
    def _calculate_rds_cost_impact(self, tf_class: str, actual_class: str) -> str:
        """Calculate approximate cost impact of RDS instance class drift"""
        # Simplified cost impact calculation
        class_costs = {
            'db.t3.micro': 0.017, 'db.t3.small': 0.034, 'db.t3.medium': 0.068,
            'db.t3.large': 0.136, 'db.t3.xlarge': 0.272, 'db.t3.2xlarge': 0.544
        }
        
        tf_cost = class_costs.get(tf_class, 0)
        actual_cost = class_costs.get(actual_class, 0)
        
        if tf_cost and actual_cost:
            monthly_diff = (actual_cost - tf_cost) * 24 * 30
            return f"Approximately ${monthly_diff:.2f}/month difference"
        
        return "Cost impact calculation unavailable"
    
    def _calculate_lambda_cost_impact(self, tf_memory: int, actual_memory: int) -> str:
        """Calculate approximate cost impact of Lambda memory drift"""
        # Simplified Lambda cost calculation (per GB-second)
        cost_per_gb_second = 0.0000166667
        
        # Assume 1 million invocations per month, 1 second average duration
        monthly_invocations = 1000000
        monthly_seconds = monthly_invocations * 1
        
        tf_cost = (tf_memory / 1024) * monthly_seconds * cost_per_gb_second
        actual_cost = (actual_memory / 1024) * monthly_seconds * cost_per_gb_second
        
        monthly_diff = actual_cost - tf_cost
        return f"Approximately ${monthly_diff:.2f}/month difference (based on 1M invocations)"
    
    def generate_remediation_suggestions(self) -> None:
        """Generate automated remediation suggestions"""
        all_drift = (self.drift_results['critical_drift'] + 
                    self.drift_results['major_drift'] + 
                    self.drift_results['minor_drift'])
        
        # Group by resource type for batch remediation
        resource_groups = {}
        for drift in all_drift:
            resource_type = drift['resource_type']
            if resource_type not in resource_groups:
                resource_groups[resource_type] = []
            resource_groups[resource_type].append(drift)
        
        # Generate suggestions for each resource type
        for resource_type, drifts in resource_groups.items():
            if resource_type == 'VPC':
                self.drift_results['remediation_suggestions'].append({
                    'resource_type': resource_type,
                    'action': 'terraform_import',
                    'command': f'terraform import aws_vpc.main <vpc_id>',
                    'description': 'Import existing VPC configuration into Terraform state'
                })
            elif resource_type == 'RDS':
                self.drift_results['remediation_suggestions'].append({
                    'resource_type': resource_type,
                    'action': 'terraform_plan_apply',
                    'command': 'terraform plan -out=drift-fix.tfplan && terraform apply drift-fix.tfplan',
                    'description': 'Apply Terraform configuration to fix RDS drift'
                })
            elif resource_type == 'Lambda':
                self.drift_results['remediation_suggestions'].append({
                    'resource_type': resource_type,
                    'action': 'lambda_update',
                    'command': 'aws lambda update-function-configuration --function-name <name> --runtime <runtime>',
                    'description': 'Update Lambda function configuration to match Terraform'
                })
    
    def generate_ci_cd_integration(self) -> None:
        """Generate CI/CD pipeline integration recommendations"""
        total_drift = len(self.drift_results['critical_drift'] + 
                         self.drift_results['major_drift'] + 
                         self.drift_results['minor_drift'])
        
        if total_drift > 0:
            self.drift_results['ci_cd_integration'] = {
                'pipeline_action': 'BLOCK_DEPLOYMENT' if len(self.drift_results['critical_drift']) > 0 else 'WARN_AND_CONTINUE',
                'automated_fix': total_drift <= 5,  # Only auto-fix if drift is manageable
                'manual_review_required': len(self.drift_results['critical_drift']) > 0,
                'recommended_checks': [
                    'Add drift detection to pre-deployment phase',
                    'Implement automatic state refresh before deployment',
                    'Add drift monitoring to post-deployment validation'
                ]
            }


def handler(event, context):
    """
    Enhanced Lambda handler for advanced drift detection
    """
    try:
        logger.info("Starting advanced infrastructure drift detection")
        
        # Get environment variables
        state_bucket = os.environ['TERRAFORM_STATE_BUCKET']
        state_key = os.environ['TERRAFORM_STATE_KEY']
        sns_topic = os.environ['SNS_TOPIC_ARN']
        environment = os.environ['ENVIRONMENT']
        
        # Initialize drift analyzer
        analyzer = DriftAnalyzer(environment, os.environ.get('AWS_REGION', 'us-east-1'))
        
        # Download and analyze Terraform state
        state_data = download_terraform_state(state_bucket, state_key)
        terraform_resources = parse_terraform_resources(state_data)
        
        # Run parallel drift analysis
        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = []
            
            if 'vpcs' in terraform_resources:
                futures.append(executor.submit(analyzer.analyze_vpc_drift, terraform_resources['vpcs']))
            if 'rds_instances' in terraform_resources:
                futures.append(executor.submit(analyzer.analyze_rds_drift, terraform_resources['rds_instances']))
            if 'lambda_functions' in terraform_resources:
                futures.append(executor.submit(analyzer.analyze_lambda_drift, terraform_resources['lambda_functions']))
            
            # Wait for all analyses to complete
            for future in as_completed(futures):
                try:
                    future.result()
                except Exception as e:
                    logger.error(f"Drift analysis failed: {str(e)}")
        
        # Generate remediation suggestions and CI/CD integration
        analyzer.generate_remediation_suggestions()
        analyzer.generate_ci_cd_integration()
        
        # Calculate drift metrics
        total_drift = len(analyzer.drift_results['critical_drift'] + 
                         analyzer.drift_results['major_drift'] + 
                         analyzer.drift_results['minor_drift'])
        
        critical_count = len(analyzer.drift_results['critical_drift'])
        major_count = len(analyzer.drift_results['major_drift'])
        minor_count = len(analyzer.drift_results['minor_drift'])
        
        # Publish enhanced metrics
        publish_enhanced_metrics(environment, total_drift, critical_count, major_count, minor_count)
        
        # Send notifications if drift detected
        if total_drift > 0:
            send_advanced_notification(sns_topic, analyzer.drift_results, environment)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'timestamp': datetime.utcnow().isoformat(),
                'environment': environment,
                'drift_summary': {
                    'total_drift': total_drift,
                    'critical_drift': critical_count,
                    'major_drift': major_count,
                    'minor_drift': minor_count
                },
                'drift_details': analyzer.drift_results,
                'analysis_type': 'ADVANCED'
            })
        }
        
    except Exception as e:
        logger.error(f"Advanced drift detection failed: {str(e)}")
        
        # Send error notification
        try:
            send_error_notification(sns_topic, str(e), environment)
        except:
            pass
            
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat(),
                'analysis_type': 'ADVANCED'
            })
        }


def download_terraform_state(bucket: str, key: str) -> Dict:
    """Download and parse Terraform state file"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        return json.loads(response['Body'].read())
    except Exception as e:
        logger.error(f"Failed to download Terraform state: {str(e)}")
        raise


def parse_terraform_resources(state_data: Dict) -> Dict:
    """Parse Terraform state to extract resource configurations"""
    resources = {
        'vpcs': [],
        'rds_instances': [],
        'lambda_functions': []
    }
    
    if 'resources' not in state_data:
        return resources
    
    for resource in state_data['resources']:
        resource_type = resource.get('type', '')
        instances = resource.get('instances', [])
        
        for instance in instances:
            attributes = instance.get('attributes', {})
            
            if resource_type == 'aws_vpc':
                resources['vpcs'].append({
                    'id': attributes.get('id'),
                    'cidr_block': attributes.get('cidr_block'),
                    'tags': attributes.get('tags', {})
                })
            elif resource_type == 'aws_db_instance':
                resources['rds_instances'].append({
                    'identifier': attributes.get('identifier'),
                    'instance_class': attributes.get('instance_class'),
                    'backup_retention_period': attributes.get('backup_retention_period'),
                    'tags': attributes.get('tags', {})
                })
            elif resource_type == 'aws_lambda_function':
                resources['lambda_functions'].append({
                    'function_name': attributes.get('function_name'),
                    'runtime': attributes.get('runtime'),
                    'memory_size': attributes.get('memory_size'),
                    'tags': attributes.get('tags', {})
                })
    
    return resources


def publish_enhanced_metrics(environment: str, total_drift: int, critical: int, major: int, minor: int) -> None:
    """Publish enhanced drift metrics to CloudWatch"""
    try:
        metric_data = [
            {
                'MetricName': 'TotalDrift',
                'Value': total_drift,
                'Unit': 'Count',
                'Dimensions': [{'Name': 'Environment', 'Value': environment}]
            },
            {
                'MetricName': 'CriticalDrift',
                'Value': critical,
                'Unit': 'Count',
                'Dimensions': [{'Name': 'Environment', 'Value': environment}]
            },
            {
                'MetricName': 'MajorDrift',
                'Value': major,
                'Unit': 'Count',
                'Dimensions': [{'Name': 'Environment', 'Value': environment}]
            },
            {
                'MetricName': 'MinorDrift',
                'Value': minor,
                'Unit': 'Count',
                'Dimensions': [{'Name': 'Environment', 'Value': environment}]
            }
        ]
        
        cloudwatch_client.put_metric_data(
            Namespace='Custom/AdvancedInfrastructureDrift',
            MetricData=metric_data
        )
        
        logger.info("Published enhanced drift metrics to CloudWatch")
        
    except Exception as e:
        logger.error(f"Failed to publish enhanced metrics: {str(e)}")


def send_advanced_notification(topic_arn: str, drift_results: Dict, environment: str) -> None:
    """Send advanced drift notification with remediation suggestions"""
    try:
        total_drift = len(drift_results['critical_drift'] + 
                         drift_results['major_drift'] + 
                         drift_results['minor_drift'])
        
        subject = f"🔍 Advanced Infrastructure Drift Detected - {environment.upper()}"
        
        message = f"""
Advanced Infrastructure Drift Detection Alert

Environment: {environment}
Detection Time: {datetime.utcnow().isoformat()}
Total Drift Items: {total_drift}

DRIFT SUMMARY:
- Critical Drift: {len(drift_results['critical_drift'])} items
- Major Drift: {len(drift_results['major_drift'])} items  
- Minor Drift: {len(drift_results['minor_drift'])} items

CRITICAL DRIFT ITEMS:
"""
        
        for drift in drift_results['critical_drift']:
            message += f"""
❌ {drift['resource_type']} - {drift['resource_id']}
   Type: {drift['drift_type']}
   Details: {drift['details']}
"""
        
        message += f"""

REMEDIATION SUGGESTIONS:
"""
        
        for suggestion in drift_results['remediation_suggestions']:
            message += f"""
🔧 {suggestion['resource_type']}: {suggestion['description']}
   Command: {suggestion['command']}
"""
        
        if drift_results['ci_cd_integration']:
            ci_cd = drift_results['ci_cd_integration']
            message += f"""

CI/CD INTEGRATION RECOMMENDATIONS:
- Pipeline Action: {ci_cd['pipeline_action']}
- Automated Fix Available: {ci_cd['automated_fix']}
- Manual Review Required: {ci_cd['manual_review_required']}

Recommended Checks:
"""
            for check in ci_cd['recommended_checks']:
                message += f"  • {check}\n"
        
        message += f"""

NEXT STEPS:
1. Review critical drift items immediately
2. Apply suggested remediation commands
3. Update CI/CD pipeline with drift prevention
4. Monitor for recurring drift patterns

This is an automated alert from the Advanced Infrastructure Drift Detection system.
"""
        
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info("Sent advanced drift notification")
        
    except Exception as e:
        logger.error(f"Failed to send advanced drift notification: {str(e)}")


def send_error_notification(topic_arn: str, error_message: str, environment: str) -> None:
    """Send error notification for drift detection failures"""
    try:
        subject = f"❌ Advanced Drift Detection Failed - {environment.upper()}"
        
        message = f"""
Advanced Infrastructure Drift Detection Error

Environment: {environment}
Error Time: {datetime.utcnow().isoformat()}
Error Message: {error_message}

The advanced drift detection process encountered an error and could not complete successfully.

This may indicate:
1. Terraform state file access issues
2. AWS API permission problems
3. Lambda function configuration issues
4. AWS service availability problems

Please investigate immediately as drift detection is critical for infrastructure reliability.
"""
        
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info("Sent error notification")
        
    except Exception as e:
        logger.error(f"Failed to send error notification: {str(e)}")
