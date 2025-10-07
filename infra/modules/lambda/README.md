# Lambda Module

This module creates an AWS Lambda function with the following features:
- VPC integration
- Auto-scaling configuration
- Provisioned concurrency
- CloudWatch alarms
- Connection pooling layer
- IAM roles and policies
- Security group configuration

## Features

- **Auto Scaling**: Automatically scales based on concurrent executions
- **Monitoring**: CloudWatch alarms for errors and duration
- **Security**: VPC deployment with security groups
- **Database Access**: Secure access to RDS via Secrets Manager
- **Connection Pooling**: PostgreSQL connection pooling layer

## Usage

```hcl
module "lambda" {
  source = "./modules/lambda"

  function_name     = "contact-form"
  lambda_zip_path   = "lambda.zip"
  lambda_role_name  = "lambda-exec-role"
  aws_region        = "us-east-1"
  db_secret_arn     = "arn:aws:secretsmanager:region:account:secret:name"
  
  tags = {
    Environment = "production"
    Project     = "contact-form"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| function_name | Name of the Lambda function | string | "contact-form" | no |
| lambda_zip_path | Path to the Lambda deployment package | string | "lambda.zip" | yes |
| lambda_role_name | Name of the IAM role for Lambda | string | - | yes |
| runtime | Lambda runtime | string | "nodejs18.x" | no |
| timeout | Lambda function timeout in seconds | number | 10 | no |
| aws_region | AWS region | string | - | yes |
| db_secret_arn | ARN of the Secrets Manager secret for DB credentials | string | - | yes |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_name | Name of the Lambda function |
| lambda_function_arn | ARN of the Lambda function |
| lambda_invoke_arn | Invoke ARN of the Lambda function |
| lambda_security_group_id | ID of the Lambda security group |
| lambda_role_arn | ARN of the Lambda execution role |
| lambda_role_name | Name of the Lambda execution role |
| lambda_cloudwatch_log_group | Name of the CloudWatch log group |
| lambda_scaling_target_id | ID of the Lambda auto scaling target |

## Resources Created

- AWS Lambda function with VPC configuration
- Auto scaling target and policy
- Provisioned concurrency configuration
- CloudWatch alarms for monitoring
- Security group for VPC access
- IAM role and policies
- Lambda layer for connection pooling