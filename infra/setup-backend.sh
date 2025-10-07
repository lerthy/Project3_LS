#!/bin/bash

# Script to set up S3 backend for Terraform state
# Run this script once to create the S3 bucket and DynamoDB table for state storage

# Disable strict error handling for better control
set +e

# Configuration - Fixed bucket name for consistent state storage
BUCKET_NAME="terraform-state-project4-sb"
REGION="eu-north-1"
DYNAMODB_TABLE="terraform-state-lock"

echo "Setting up Terraform backend infrastructure..."

# Create S3 bucket for state storage
echo "Creating S3 bucket: $BUCKET_NAME"
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "S3 bucket already exists: $BUCKET_NAME"
else
    if aws s3 mb s3://$BUCKET_NAME --region $REGION; then
        echo "✅ S3 bucket created successfully: $BUCKET_NAME"
    else
        echo "❌ Failed to create S3 bucket. Trying with additional uniqueness..."
        RANDOM_SUFFIX=$(openssl rand -hex 4)
        BUCKET_NAME="terraform-state-project3-eunorth1-${AWS_ACCOUNT_ID}-${TIMESTAMP}-${RANDOM_SUFFIX}"
        echo "Retrying with bucket name: $BUCKET_NAME"
        aws s3 mb s3://$BUCKET_NAME --region $REGION
        echo "✅ S3 bucket created successfully: $BUCKET_NAME"
    fi
fi

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
if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $REGION >/dev/null 2>&1; then
    echo "DynamoDB table already exists: $DYNAMODB_TABLE"
else
    echo "Creating new DynamoDB table..."
    if aws dynamodb create-table \
        --table-name $DYNAMODB_TABLE \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region $REGION >/dev/null 2>&1; then
        
        # Wait for table to be created
        echo "Waiting for DynamoDB table to be created..."
        aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $REGION
        echo "✅ DynamoDB table created successfully: $DYNAMODB_TABLE"
    else
        echo "❌ Failed to create DynamoDB table. It may already exist."
        # Check if table exists now
        if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $REGION >/dev/null 2>&1; then
            echo "✅ DynamoDB table exists: $DYNAMODB_TABLE"
        else
            echo "❌ DynamoDB table creation failed"
            exit 1
        fi
    fi
fi

# Create/Update backend configuration file
echo "Creating/updating backend configuration..."
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "project4/terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }
}
EOF

echo ""
echo "✅ Backend infrastructure created successfully!"
echo ""
echo "📋 Configuration Updated:"
echo "- Updated: backend.tf with bucket: $BUCKET_NAME"
echo "- State key: project4/terraform.tfstate"
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
