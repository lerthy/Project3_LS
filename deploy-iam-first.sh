#!/bin/bash

# Phase 1: Deploy IAM changes first
echo "Phase 1: Deploying IAM changes..."

# Apply only IAM module
terraform apply -target=module.iam -auto-approve

# Wait for IAM changes to propagate (AWS eventual consistency)
echo "Waiting for IAM changes to propagate..."
sleep 30

# Phase 2: Deploy the rest of the infrastructure
echo "Phase 2: Deploying remaining infrastructure..."

# Apply everything
terraform apply -auto-approve

echo "Deployment complete!"