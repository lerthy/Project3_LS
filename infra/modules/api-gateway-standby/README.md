# API Gateway Standby Module

This module creates an API Gateway REST API in the standby region with the following features:
- Regional endpoint configuration
- Access logging to CloudWatch
- CloudWatch alarms for monitoring
- Integration with Lambda functions
- CORS configuration
- Stage deployment

## Features

- **Regional Endpoint**: Optimized for failover scenarios
- **Logging**: Comprehensive access logging to CloudWatch
- **Monitoring**: CloudWatch alarms for 5XX errors
- **Security**: WAF integration ready
- **Performance**: Stage caching configuration

## Usage

```hcl
module "api_gateway_standby" {
  source = "./modules/api-gateway-standby"
  
  providers = {
    aws.standby = aws.us-west-2
  }

  environment    = "standby"
  lambda_invoke_arn = module.lambda_standby.invoke_arn
  
  tags = {
    Environment = "standby"
    Region     = "us-west-2"
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
| environment | Environment name | string | - | yes |
| lambda_invoke_arn | Lambda function invoke ARN | string | - | yes |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| rest_api_id | ID of the API Gateway REST API |
| rest_api_arn | ARN of the API Gateway REST API |
| api_endpoint | URL of the API Gateway endpoint |
| stage_name | Name of the API Gateway stage |
| stage_arn | ARN of the API Gateway stage |
| execution_arn | Execution ARN for Lambda permission |
| log_group_arn | ARN of the CloudWatch log group |
| log_group_name | Name of the CloudWatch log group |

## Resources Created

- API Gateway REST API
- API Gateway stage
- API Gateway deployment
- CloudWatch log group
- CloudWatch alarms
- CORS configuration
- Lambda integration
- Method configuration