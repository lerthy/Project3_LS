#!/bin/bash
# Remove disaster recovery module from Terraform state
# This is needed because we deleted the module code but resources still exist in state

cd infra

echo "🗑️  Removing disaster recovery resources from Terraform state..."

# List all disaster recovery resources
terraform state list | grep "module.disaster_recovery" | while read resource; do
    echo "Removing: $resource"
    terraform state rm "$resource" || true
done

echo "✅ Disaster recovery resources removed from state"
echo "⚠️  Note: AWS resources still exist but Terraform will no longer manage them"
echo "💡 To delete AWS resources, manually delete them from AWS Console or use AWS CLI"
