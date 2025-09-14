#!/bin/bash

# Script to set up S3 backend for Terraform state
# Run this script once to create the S3 bucket and DynamoDB table for state storage

set -e

# Configuration
BUCKET_NAME="project3-terraform-state-$(date +%s)"
REGION="us-east-1"
DYNAMODB_TABLE="terraform-state-lock"

echo "Setting up Terraform backend infrastructure..."

# Create S3 bucket for state storage
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Enable versioning on the bucket
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "Enabling server-side encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access
echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking: $DYNAMODB_TABLE"
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $REGION

# Wait for table to be created
echo "Waiting for DynamoDB table to be created..."
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $REGION

echo ""
echo "✅ Backend infrastructure created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Update your backend.tf file with these values:"
echo "   bucket  = \"$BUCKET_NAME\""
echo "   key     = \"project3/terraform.tfstate\""
echo "   region  = \"$REGION\""
echo "   encrypt = true"
echo "   dynamodb_table = \"$DYNAMODB_TABLE\""
echo ""
echo "2. Run: terraform init -migrate-state"
echo "3. Run: terraform plan"
echo ""
echo "🔐 Security:"
echo "- S3 bucket: $BUCKET_NAME"
echo "- DynamoDB table: $DYNAMODB_TABLE"
echo "- Region: $REGION"
echo "- Encryption: Enabled"
echo "- Public access: Blocked"
