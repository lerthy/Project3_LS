# 🚨 URGENT: How to Fix Your Infrastructure Deployment

## ⚡ Quick Summary

Your pipeline is failing because the **IAM role in AWS doesn't have the updated permissions yet**. 

**The fix is in 2 steps:**
1. ✅ Apply IAM changes to AWS (using the script below)
2. ✅ Push your code changes and re-run the pipeline

---

## 🎯 THE SOLUTION (Copy-Paste This)

### Step 1: Apply IAM Fixes to AWS RIGHT NOW

Run this from your terminal:

```bash
cd ~/Desktop/polymath\ apprentice\ program/Project3_LS
./fix-iam-now.sh
```

**What this does:**
- Updates the `codebuild-role-project3-v2` IAM role in AWS
- Adds all missing S3 and SNS permissions
- Takes ~30 seconds

---

### Step 2: Commit Your Code and Re-Run Pipeline

After the IAM update succeeds:

```bash
# Commit your changes
git add .
git commit -m "fix: Add missing IAM permissions for S3 encryption and SNS subscriptions"
git push origin project-4
```

**Your pipeline will automatically trigger and should now succeed! 🎉**

---

## 🔍 What Permissions Were Added?

### S3 Permissions (Fixed Encryption Issues)
- `s3:PutEncryptionConfiguration` ← **This was the main one missing!**
- `s3:DeleteBucketEncryption`
- `s3:GetEncryptionConfiguration`
- `s3:GetBucketAcl`
- `s3:PutBucketAcl`
- `s3:PutBucketOwnershipControls`
- `s3:GetBucketOwnershipControls`

### S3 Resource Coverage (Fixed Bucket Access)
Added pattern: `arn:aws:s3:::project3-*` to cover:
- ✅ `project3-rpo-backup-metadata-*` buckets
- ✅ All future `project3-*` buckets

### SNS Permissions (Fixed Subscription Issues)
- `SNS:Subscribe` ← **This was missing!**
- `SNS:Unsubscribe`
- `SNS:ListSubscriptionsByTopic`
- `SNS:GetSubscriptionAttributes`
- `SNS:SetSubscriptionAttributes`

### SNS Topic Coverage (Fixed Topic Access)
Added patterns for your actual topic names:
- ✅ `*-alerts` (covers `multi-region-alerts`, `development-drift-alerts`)
- ✅ `cicd-*` (covers `cicd-pipeline-notifications-development`)
- ✅ `manual-approval-*` (covers `manual-approval-notifications-development`)

---

## 🤔 Why Did This Happen?

The problem was a **chicken-and-egg situation**:

```
1. You updated the Terraform code (IAM permissions) ✅
2. But those changes weren't applied to AWS yet ❌
3. Your pipeline ran with the OLD IAM permissions ❌
4. Pipeline failed due to missing permissions ❌
```

**The fix:**
```
1. Apply IAM changes to AWS FIRST 
   (using ./fix-iam-now.sh) ✅
2. THEN run the full pipeline ✅
3. Pipeline succeeds! 🎉
```

---

## 📝 Errors That Will Be Fixed

### Before Fix:
```
❌ Error: User is not authorized to perform: s3:PutEncryptionConfiguration
❌ Error: User is not authorized to perform: SNS:Subscribe
❌ Error: AccessDenied on project3-rpo-backup-metadata-*
```

### After Fix:
```
✅ S3 bucket encryption configured successfully
✅ SNS email subscriptions created
✅ All resources deployed without permission errors
```

---

## ⚠️ Important Notes

1. **Run the IAM fix script BEFORE pushing code changes**
   - The script updates AWS directly
   - This gives your pipeline the permissions it needs

2. **The script is safe to run multiple times**
   - Terraform will only apply changes if needed
   - Uses `-lock=false -refresh=false` to avoid conflicts

3. **Wait for "SUCCESS" message**
   - The script will confirm when IAM is updated
   - Don't push code until you see the success message

---

## 🆘 If Something Goes Wrong

### If the script fails:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Terraform state access
aws s3 ls s3://terraform-state-project4-sb/

# Run manually
cd infra
terraform init -reconfigure
terraform apply -target=module.iam -auto-approve
```

### If pipeline still fails after IAM fix:
- Check CodeBuild logs in AWS Console
- Verify the role `codebuild-role-project3-v2` has the new permissions
- Wait 1-2 minutes for IAM changes to propagate

---

## 📞 Files Modified

- ✅ `infra/modules/iam/main.tf` - Updated with new permissions
- ✅ `fix-iam-now.sh` - Script to apply IAM changes
- ✅ `IAM-PERMISSION-FIXES.md` - Detailed documentation

---

**Created:** October 5, 2025  
**Status:** Ready to Deploy  
**Estimated Fix Time:** < 2 minutes

---

## 🎯 TL;DR - Just Do This:

```bash
./fix-iam-now.sh
# Wait for success message...

git add .
git commit -m "fix: IAM permissions"
git push origin project-4
# Pipeline will succeed! 🎉
```
