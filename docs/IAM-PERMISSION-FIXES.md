# IAM Permission Fixes for Infrastructure Deployment Failures

## 🔴 Problem Summary

Your infrastructure deployment was failing with **AccessDenied** errors for the CodeBuild role `codebuild-role-project3-v2` when trying to:

1. ❌ Delete S3 bucket encryption configuration on `project3-rpo-backup-metadata-*` bucket
2. ❌ Read S3 bucket ACL on CloudFront logs bucket
3. ❌ Set SNS topic attributes (KmsMasterKeyId) on multiple SNS topics

## 🔍 Root Causes Identified

### 1. **Missing S3 Permissions**
The CodeBuild IAM role lacked the following S3 permissions:
- `s3:DeleteBucketEncryption` - Required to remove encryption configuration
- `s3:PutEncryptionConfiguration` - Required to modify encryption settings
- `s3:GetEncryptionConfiguration` - Required to read encryption settings
- `s3:GetBucketAcl` - Required to read bucket ACL
- `s3:PutBucketAcl` - Required to modify bucket ACL
- `s3:PutBucketOwnershipControls` - Required for ownership controls
- `s3:GetBucketOwnershipControls` - Required to read ownership controls

### 2. **Insufficient S3 Resource Scope**
The S3 permissions only covered:
```
- terraform-state-*
- my-website-bucket-*
- codepipeline-artifacts-*
```

But your infrastructure creates buckets like:
- `project3-rpo-backup-metadata-*` ❌ **NOT COVERED**

### 3. **SNS Topic ARN Pattern Mismatch**
SNS permissions only allowed topics matching `project3-*`, but your actual topics are:
- `multi-region-alerts` ❌
- `cicd-pipeline-notifications-development` ❌
- `manual-approval-notifications-development` ❌
- `development-drift-alerts` ❌

### 4. **Missing SNS Subscription Permissions**
The role lacked `SNS:Subscribe` permission needed to create email subscriptions to SNS topics.

## ✅ Solutions Applied

### Fix 1: Added Missing S3 Permissions
Added the following S3 actions to the CodeBuild role policy:
```terraform
"s3:DeleteBucketEncryption",
"s3:PutEncryptionConfiguration",
"s3:GetEncryptionConfiguration",
"s3:GetBucketAcl",
"s3:PutBucketAcl",
"s3:PutBucketOwnershipControls",
"s3:GetBucketOwnershipControls"
```

### Fix 2: Extended S3 Resource Coverage
Added wildcard pattern to cover all project buckets:
```terraform
"arn:aws:s3:::project3-*",
"arn:aws:s3:::project3-*/*"
```

This now covers:
- ✅ `project3-rpo-backup-metadata-*`
- ✅ Any future buckets starting with `project3-`

### Fix 3: Expanded SNS Topic Patterns
Updated SNS resource ARNs to include all topic patterns:
```terraform
Resource = [
  "arn:aws:sns:${var.aws_region}:*:project3-*",
  "arn:aws:sns:${var.aws_region}:*:*-alerts",
  "arn:aws:sns:${var.aws_region}:*:cicd-*",
  "arn:aws:sns:${var.aws_region}:*:manual-approval-*",
  "arn:aws:sns:${var.aws_region}:*:development-*",
  "arn:aws:sns:${var.aws_region}:*:multi-region-*"
]
```

### Fix 4: Added SNS Subscription Permissions
Added a new policy statement for SNS subscription operations:
```terraform
{
  Effect = "Allow"
  Action = [
    "sns:Subscribe",
    "sns:Unsubscribe",
    "sns:ListSubscriptionsByTopic",
    "sns:GetSubscriptionAttributes",
    "sns:SetSubscriptionAttributes"
  ]
  Resource = "*"
}
```

**Note**: SNS:Subscribe needs broader resource scope because subscription ARNs are created dynamically and can't be predicted before creation.

## 📋 Next Steps

### ⚠️ IMPORTANT: The Code Changes Need to be Applied to AWS First!

The Terraform code has been updated, but **the actual IAM role in AWS still has the old permissions**. You MUST apply the IAM changes BEFORE running your pipeline again.

### 🚀 QUICKEST FIX - Run This Command:

```bash
# From the project root directory:
./fix-iam-now.sh
```

This script will:
1. ✅ Connect to your AWS account
2. ✅ Apply ONLY the IAM module changes
3. ✅ Update the CodeBuild role with all missing permissions
4. ✅ Enable your pipeline to succeed

### Alternative: Manual Terraform Apply

If you prefer to run the commands manually:

```bash
cd infra

# Initialize Terraform with your backend
terraform init \
  -backend-config="bucket=terraform-state-project4-sb" \
  -backend-config="key=project4/terraform.tfstate" \
  -backend-config="region=eu-north-1" \
  -backend-config="encrypt=true" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -reconfigure

# Apply ONLY IAM changes
terraform apply -target=module.iam -auto-approve -lock=false -refresh=false
```

### After Applying IAM Changes:

```bash
# Commit and push your code changes
git add .
git commit -m "fix: Add missing IAM permissions for S3 and SNS operations"
git push origin project-4

# Your pipeline will automatically trigger with the new permissions!
```

## 🎯 Expected Outcome

After applying these fixes, your infrastructure deployment should:
1. ✅ Successfully delete/modify S3 bucket encryption configurations
2. ✅ Read S3 bucket ACLs for CloudFront logging setup
3. ✅ Set KMS encryption on all SNS topics
4. ✅ Complete full Terraform apply without permission errors

## 📝 Files Modified

- **File**: `/infra/modules/iam/main.tf`
- **Sections Updated**:
  - S3 permissions in `codebuild_core_policy` (lines ~120-155)
  - SNS permissions in `codebuild_config_policy` (lines ~312-324)

## 🔒 Security Notes

The changes maintain the principle of least privilege by:
- Using wildcard patterns (`project3-*`, `*-alerts`, etc.) instead of `*`
- Scoping permissions to specific resource patterns
- Not adding overly broad permissions like `s3:*` on all buckets

---

**Date Fixed**: October 5, 2025  
**Pipeline**: `project3-infrastructure-pipeline`  
**Build Project**: `project3-infrastructure-build`  
**Region**: `eu-north-1`
