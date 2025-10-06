# Latest Fixes - Secrets Manager & RDS Issues

## 🆕 NEW Issues Fixed (Oct 5, 2025 - 21:30)

### 1️⃣ Secrets Manager Multi-Region Access
**Error:** `secretsmanager:PutSecretValue` denied on `us-west-2` secret

**Fix:** Changed Secrets Manager permission from single-region to multi-region:
```terraform
# OLD - only eu-north-1:
"arn:aws:secretsmanager:eu-north-1:*:secret:project3/*"

# NEW - all regions (for disaster recovery):
"arn:aws:secretsmanager:*:*:secret:project3/*"
```

### 2️⃣ RDS Performance Insights KMS Key
**Error:** `You can't change your Performance Insights KMS key`

**Fix:** Added lifecycle rule to prevent Terraform from modifying immutable RDS attributes:
```terraform
lifecycle {
  ignore_changes = [performance_insights_kms_key_id]
}
```

---

## 🚀 Quick Fix

```bash
# Apply the fixes
./fix-iam-now.sh

# Commit and push
git add .
git commit -m "fix: Multi-region Secrets Manager and RDS lifecycle"
git push origin project-4
```

---

## 📊 All Fixes Summary

| Fix # | Issue | Status |
|-------|-------|--------|
| 1 | S3 PutEncryptionConfiguration | ✅ Fixed |
| 2 | S3 DeleteBucketEncryption | ✅ Fixed |
| 3 | S3 GetBucketAcl | ✅ Fixed |
| 4 | S3 project3-* bucket access | ✅ Fixed |
| 5 | SNS Subscribe permission | ✅ Fixed |
| 6 | SNS topic name patterns | ✅ Fixed |
| 7 | **Secrets Manager multi-region** | ✅ **NEW** |
| 8 | **RDS KMS key lifecycle** | ✅ **NEW** |

---

**Files Changed:**
- `infra/modules/iam/main.tf` (Secrets Manager permission)
- `infra/modules/rds/main.tf` (RDS lifecycle rule)
