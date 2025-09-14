# Terraform Backend Setup

This document explains how to set up remote state storage for your Terraform infrastructure.

## 🚨 **Current State: Local Only**

Right now, Terraform state is stored locally in `terraform.tfstate` files. This means:
- ❌ State is not shared between team members
- ❌ State is not backed up
- ❌ CI/CD pipelines can't access the state
- ❌ Risk of state corruption or loss

## ✅ **Solution: S3 Backend with DynamoDB Locking**

We'll use AWS S3 to store the state file and DynamoDB for state locking.

### **Step 1: Create Backend Infrastructure**

Run the setup script to create the required AWS resources:

```bash
cd infra
./setup-backend.sh
```

This script will create:
- **S3 Bucket**: For storing Terraform state files
- **DynamoDB Table**: For state locking (prevents concurrent modifications)
- **Security**: Encryption enabled, public access blocked

### **Step 2: Configure Backend**

After running the script, update `backend.tf` with the provided values:

```hcl
terraform {
  backend "s3" {
    bucket  = "your-terraform-state-bucket-name"
    key     = "project3/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### **Step 3: Migrate State**

Initialize Terraform with the new backend:

```bash
terraform init -migrate-state
```

When prompted, type `yes` to migrate your existing state to the S3 backend.

### **Step 4: Configure CI/CD**

For CodeBuild to use the backend, set these environment variables in your CodeBuild project:

```
TF_STATE_BUCKET=your-terraform-state-bucket-name
TF_STATE_KEY=project3/terraform.tfstate
TF_STATE_REGION=us-east-1
TF_STATE_TABLE=terraform-state-lock
```

## 🔐 **Security Features**

- **Encryption**: State files encrypted at rest in S3
- **Access Control**: Only your AWS account can access the bucket
- **Versioning**: S3 bucket versioning enabled for state file history
- **Locking**: DynamoDB prevents concurrent state modifications
- **Public Access**: Blocked on S3 bucket

## 📋 **Benefits**

- ✅ **Shared State**: Team members can work on the same infrastructure
- ✅ **Backup**: State is automatically backed up in S3
- ✅ **CI/CD**: CodeBuild can access and modify state
- ✅ **Locking**: Prevents state corruption from concurrent runs
- ✅ **History**: Versioning allows you to see state changes over time
- ✅ **Security**: Encrypted and access-controlled

## 🚀 **After Setup**

Once configured, all Terraform operations will:
1. Download state from S3
2. Acquire a lock in DynamoDB
3. Make changes
4. Upload new state to S3
5. Release the lock

This ensures safe, shared state management for your infrastructure.
