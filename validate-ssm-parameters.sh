#!/bin/bash

# Script to validate SSM parameters are properly configured
# Usage: ./validate-ssm-parameters.sh

set -e

echo "🔍 Validating SSM Parameters..."
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check SSM parameter
check_ssm_parameter() {
    local param_name=$1
    local description=$2
    
    echo -n "Checking $description ($param_name)... "
    
    if aws ssm get-parameter --name "$param_name" --query 'Parameter.Value' --output text >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Function to check secure parameter
check_secure_parameter() {
    local param_name=$1
    local description=$2
    
    echo -n "Checking $description ($param_name)... "
    
    if aws ssm get-parameter --name "$param_name" --with-decryption --query 'Parameter.Value' --output text >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

echo -e "${YELLOW}S3 Module Parameters:${NC}"
check_ssm_parameter "/s3/website_bucket_name" "Website Bucket Name"
check_ssm_parameter "/s3/website_bucket_arn" "Website Bucket ARN"
check_ssm_parameter "/s3/artifacts_bucket_name" "Artifacts Bucket Name"

echo ""
echo -e "${YELLOW}CloudFront Module Parameters:${NC}"
check_ssm_parameter "/cloudfront/cloudfront_distribution_id" "CloudFront Distribution ID"
check_ssm_parameter "/cloudfront/cloudfront_domain_name" "CloudFront Domain Name"

echo ""
echo -e "${YELLOW}API Gateway Module Parameters:${NC}"
check_ssm_parameter "/api-gateway/api_gateway_id" "API Gateway ID"
check_ssm_parameter "/api-gateway/api_gateway_url" "API Gateway URL"

echo ""
echo -e "${YELLOW}Lambda Module Parameters:${NC}"
check_ssm_parameter "/lambda/lambda_function_name" "Lambda Function Name"
check_ssm_parameter "/lambda/lambda_function_arn" "Lambda Function ARN"

echo ""
echo -e "${YELLOW}RDS Module Parameters:${NC}"
check_ssm_parameter "/rds/rds_endpoint" "RDS Endpoint"
check_ssm_parameter "/rds/db_username" "Database Username"
check_ssm_parameter "/rds/db_name" "Database Name"
check_secure_parameter "/rds/db_password" "Database Password (Secure)"

echo ""
echo -e "${GREEN}✅ SSM Parameter validation complete!${NC}"
echo ""
echo "💡 You can now use these parameters in your CI/CD pipelines and applications"
echo "   Example: aws ssm get-parameter --name '/s3/website_bucket_name' --query 'Parameter.Value' --output text"
