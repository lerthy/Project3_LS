# Buildspec Integration Test

This document explains how the `validate-backend.sh` script integrates with the CI/CD pipeline.

## Integration Points

### 1. Pre-Build Validation
The script runs in the `post_build` phase after Lambda packaging but before terraform init:

```yaml
# Create Lambda deployment package  
- (cd web/lambda && zip -r ../../infra/lambda.zip .)

# Validate Terraform backend prerequisites
- echo "Validating Terraform backend prerequisites..."
- chmod +x validate-backend.sh  
- ./validate-backend.sh

# Terraform init with backend
- terraform -chdir=infra init -backend-config=...
```

### 2. Environment Variables Required
The buildspec already has the required environment variables:

```yaml
env:
  variables:
    TF_STATE_BUCKET: "terraform-state-project3-fresh"
    TF_STATE_KEY: "project3/terraform.tfstate"
    TF_STATE_REGION: "us-east-1"
    TF_STATE_TABLE: "terraform-state-lock"
```

### 3. Failure Behavior
If validation fails:
- ❌ Pipeline stops with clear error message
- 💡 Provides guidance to run `./setup-deployment.sh` first
- 🔍 Shows exactly which resources are missing

### 4. Success Flow
If validation passes:
- ✅ Confirms backend resources exist
- 📋 Shows backend configuration
- 🚀 Proceeds to terraform init with confidence

## Benefits

1. **Fail Fast**: Catches backend issues before terraform init
2. **Clear Errors**: Provides actionable error messages
3. **Documentation**: Shows backend configuration for debugging
4. **Reliability**: Prevents chicken-and-egg problems your colleague mentioned

## Testing

Local test successful:
```bash
export TF_STATE_BUCKET="terraform-state-project3-fresh"
export TF_STATE_REGION="us-east-1" 
export TF_STATE_TABLE="terraform-state-lock"
./validate-backend.sh
# ✅ Backend validation successful!
```
