#!/bin/bash
set -e

echo "=========================================="
echo "🔧 FIXING CODEPIPELINE CONFIGURATION"
echo "=========================================="
echo ""
echo "Issue: Deploy stage was using 'build_output' instead of 'source_output'"
echo "Fix: Changed input_artifacts from 'build_output' to 'source_output'"
echo ""
echo "This will allow the Deploy stage to access buildspec-infra.yml"
echo ""
echo "=========================================="
echo "Applying changes to CodePipeline..."
echo "=========================================="
echo ""

cd cicd

# Initialize if needed
terraform init -upgrade

# Apply only the pipeline resource
echo "Updating CodePipeline infrastructure..."
terraform apply -target=aws_codepipeline.infra_pipeline -auto-approve

echo ""
echo "=========================================="
echo "✅ SUCCESS!"
echo "=========================================="
echo ""
echo "The pipeline configuration has been fixed!"
echo ""
echo "🚀 Next Steps:"
echo "  1. Commit these changes:"
echo "     git add ."
echo "     git commit -m 'fix: Correct Deploy stage input artifacts to use source_output'"
echo "     git push origin project-4"
echo ""
echo "  2. The pipeline will now be able to find buildspec-infra.yml"
echo ""
echo "=========================================="
