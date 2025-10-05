#!/bin/bash
# Quick IAM Fix - Run this FIRST before triggering the pipeline

set -e

echo "=========================================="
echo "🔐 Quick IAM Permission Fix"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Update the CodeBuild IAM role in AWS"
echo "  2. Add missing S3 and SNS permissions"
echo "  3. Enable your pipeline to succeed"
echo ""
echo "Press ENTER to continue or Ctrl+C to cancel..."
read

cd "$(dirname "$0")/infra"

echo "🔄 Initializing Terraform..."
terraform init \
  -backend-config="bucket=terraform-state-project4-sb" \
  -backend-config="key=project4/terraform.tfstate" \
  -backend-config="region=eu-north-1" \
  -backend-config="encrypt=true" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -reconfigure

echo ""
echo "🎯 Applying ONLY IAM module updates..."
echo "This will add these missing permissions to codebuild-role-project3-v2:"
echo "  ✅ s3:PutEncryptionConfiguration"
echo "  ✅ s3:DeleteBucketEncryption" 
echo "  ✅ s3:GetBucketAcl"
echo "  ✅ s3:PutBucketAcl"
echo "  ✅ SNS:Subscribe"
echo "  ✅ Secrets Manager multi-region support"
echo "  ✅ Coverage for project3-* S3 buckets"
echo ""

terraform apply -target=module.iam -auto-approve -lock=false -refresh=false

echo ""
echo "=========================================="
echo "✅ SUCCESS!"
echo "=========================================="
echo ""
echo "The IAM role has been updated in AWS!"
echo ""
echo "🚀 Next Steps:"
echo "  1. Commit and push your changes:"
echo "     git add ."
echo "     git commit -m 'fix: Add missing IAM permissions for S3 and SNS'"
echo "     git push origin project-4"
echo ""
echo "  2. Your CodeBuild pipeline will now have the correct permissions!"
echo ""
echo "=========================================="
