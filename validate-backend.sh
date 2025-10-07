#!/bin/bash

# Validate Terraform Backend Prerequisites
# Run this before terraform init in CI/CD

set -e

echo "🔍 Validating Terraform backend prerequisites..."

# Check if required environment variables are set
if [ -z "$TF_STATE_BUCKET" ] || [ -z "$TF_STATE_REGION" ] || [ -z "$TF_STATE_TABLE" ]; then
    echo "❌ ERROR: Backend environment variables not set"
    echo "Required: TF_STATE_BUCKET, TF_STATE_REGION, TF_STATE_TABLE"
    exit 1
fi

# Validate S3 bucket exists and is accessible
echo "Checking S3 bucket: $TF_STATE_BUCKET"
if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" --region "$TF_STATE_REGION" 2>/dev/null; then
    echo "❌ ERROR: S3 bucket '$TF_STATE_BUCKET' does not exist or is not accessible"
    echo "💡 Run ./setup-deployment.sh first to create backend infrastructure"
    exit 1
fi

# Validate DynamoDB table exists
echo "Checking DynamoDB table: $TF_STATE_TABLE"
if ! aws dynamodb describe-table --table-name "$TF_STATE_TABLE" --region "$TF_STATE_REGION" >/dev/null 2>&1; then
    echo "❌ ERROR: DynamoDB table '$TF_STATE_TABLE' does not exist"
    echo "💡 Run ./setup-deployment.sh first to create backend infrastructure"
    exit 1
fi

echo "✅ Backend validation successful!"
echo "📋 Backend Configuration:"
echo "   S3 Bucket: $TF_STATE_BUCKET"
echo "   DynamoDB Table: $TF_STATE_TABLE"
echo "   Region: $TF_STATE_REGION"
