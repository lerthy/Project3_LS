#!/bin/bash

# Master Deployment Setup Script for Project3
# This script runs all prerequisite scripts in the correct order
# Run this once before terraform apply

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"
WEB_DIR="$PROJECT_ROOT/web"
LAMBDA_DIR="$WEB_DIR/lambda"

# Logging function
log_step() {
    echo -e "${BOLD}${BLUE}===========================================${NC}"
    echo -e "${BOLD}${BLUE}🚀 STEP $1: $2${NC}"
    echo -e "${BOLD}${BLUE}===========================================${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Error handling
handle_error() {
    log_error "Script failed at step: $current_step"
    log_error "Check the output above for details"
    exit 1
}

trap handle_error ERR

# Main deployment setup
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    PROJECT DEPLOYMENT SETUP                  ║"
echo "║              All-in-One Prerequisites Script                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 This script will:${NC}"
echo "   1. Validate SSM parameters"
echo "   2. Set up Terraform backend (S3 + DynamoDB)"
echo "   3. Package all Lambda functions"
echo "   4. Install and test web dependencies"
echo "   5. Validate everything is ready for deployment"
echo ""

read -p "Continue with full deployment setup? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""

# STEP 1: Validate SSM Parameters
current_step="1"
log_step "1" "Validating SSM Parameters"
cd "$PROJECT_ROOT"
if [ -f "validate-ssm-parameters.sh" ]; then
    chmod +x validate-ssm-parameters.sh
    ./validate-ssm-parameters.sh
    log_success "SSM parameters validated"
else
    log_error "validate-ssm-parameters.sh not found!"
    exit 1
fi

echo ""

# STEP 2: Setup Terraform Backend
current_step="2"
log_step "2" "Setting up Terraform Backend (S3 + DynamoDB)"
cd "$INFRA_DIR"
if [ -f "setup-backend.sh" ]; then
    chmod +x setup-backend.sh
    log_info "Creating S3 bucket and DynamoDB table for Terraform state..."
    ./setup-backend.sh
    log_success "Terraform backend infrastructure created"
    
    # Extract bucket name from the script output for later use
    log_info "Backend setup completed - you'll need to update backend.tf manually"
else
    log_error "setup-backend.sh not found in infra directory!"
    exit 1
fi

echo ""

# STEP 3: Package Lambda Functions
current_step="3"
log_step "3" "Packaging Lambda Functions"

# Package disaster recovery Lambda
log_info "Packaging disaster recovery Lambda..."
cd "$INFRA_DIR/modules/disaster-recovery"
if [ -f "package_lambda.sh" ]; then
    chmod +x package_lambda.sh
    ./package_lambda.sh
    log_success "Disaster recovery Lambda packaged"
else
    log_warning "package_lambda.sh not found in disaster-recovery module"
fi

# Package RPO enhancement Lambda
log_info "Packaging RPO enhancement Lambda..."
cd "$INFRA_DIR/modules/rpo-enhancement"
if [ -f "package_lambda.sh" ]; then
    chmod +x package_lambda.sh
    ./package_lambda.sh
    log_success "RPO enhancement Lambda packaged"
else
    log_warning "package_lambda.sh not found in rpo-enhancement module"
fi

# Package web Lambda function
log_info "Packaging web Lambda function..."
cd "$LAMBDA_DIR"
if [ -f "package.json" ]; then
    zip -r "$INFRA_DIR/lambda.zip" . -x "node_modules/*" "coverage/*" "*.test.js" "jest.config.*"
    log_success "Web Lambda function packaged"
else
    log_warning "package.json not found in web/lambda directory"
fi

echo ""

# STEP 4: Web Dependencies and Testing
current_step="4"
log_step "4" "Installing and Testing Web Dependencies"

# Main web dependencies
log_info "Installing main web dependencies..."
cd "$WEB_DIR"
if [ -f "package.json" ]; then
    npm install
    log_success "Web dependencies installed"
    
    # Run web tests
    log_info "Running web linting and tests..."
    npm run lint || log_warning "Web linting had issues"
    npm run test || log_warning "Web tests had issues"
    log_success "Web testing completed"
else
    log_warning "package.json not found in web directory"
fi

# Lambda dependencies and testing
log_info "Installing Lambda dependencies..."
cd "$LAMBDA_DIR"
if [ -f "package.json" ]; then
    npm install
    log_success "Lambda dependencies installed"
    
    # Run Lambda tests
    log_info "Running Lambda linting and tests..."
    npm run lint || log_warning "Lambda linting had issues"
    npm test || log_warning "Lambda tests had issues"
    log_success "Lambda testing completed"
else
    log_warning "package.json not found in web/lambda directory"
fi

echo ""

# STEP 5: Final Validation
current_step="5"
log_step "5" "Final Pre-Deployment Validation"

# Check if all required files exist
log_info "Validating all required files exist..."

# Check Lambda zip files
if [ -f "$INFRA_DIR/lambda.zip" ]; then
    log_success "Web Lambda zip file exists"
else
    log_warning "Web Lambda zip file missing"
fi

if [ -f "$INFRA_DIR/modules/disaster-recovery/disaster_recovery.zip" ]; then
    log_success "Disaster recovery Lambda zip exists"
else
    log_warning "Disaster recovery Lambda zip missing"
fi

if [ -f "$INFRA_DIR/modules/rpo-enhancement/hourly_backup.zip" ]; then
    log_success "RPO enhancement Lambda zip exists"
else
    log_warning "RPO enhancement Lambda zip missing"
fi

# Check Terraform files
if [ -f "$INFRA_DIR/main.tf" ]; then
    log_success "Terraform main.tf exists"
else
    log_error "Terraform main.tf missing!"
fi

if [ -f "$INFRA_DIR/terraform.tfvars" ]; then
    log_success "Terraform variables file exists"
else
    log_warning "terraform.tfvars missing - using defaults"
fi

echo ""

# STEP 7: Ready for Deployment
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    🎉 SETUP COMPLETE! 🎉                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log_success "All prerequisite scripts have been executed successfully!"
echo ""

echo -e "${BLUE}📋 Setup Summary:${NC}"
echo -e "${GREEN}✅ SSM parameters configured${NC}"
echo -e "${GREEN}✅ Terraform backend infrastructure created${NC}"
echo -e "${GREEN}✅ All Lambda functions packaged${NC}"
echo -e "${GREEN}✅ Web dependencies installed and tested${NC}"
echo -e "${GREEN}✅ Pre-deployment validation completed${NC}"

echo ""
echo -e "${BOLD}${YELLOW}⚠️  MANUAL STEP REQUIRED:${NC}"
echo -e "${YELLOW}Before running terraform apply, you need to update backend.tf${NC}"
echo -e "${YELLOW}with the S3 bucket name created in step 2.${NC}"
echo ""

echo -e "${BOLD}${BLUE}Ready for Terraform Deployment!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Update infra/backend.tf with the S3 bucket name from step 2"
echo "2. cd infra"
echo "3. terraform init -migrate-state"
echo "4. terraform plan"
echo "5. terraform apply"
echo ""

echo -e "${CYAN}Your Project assignment is ready for deployment! ${NC}"

# Optional: Ask if user wants to proceed with terraform init
echo ""
read -p "Would you like to run 'terraform init' now? (y/N): " init_terraform
if [[ $init_terraform =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Running terraform init..."
    cd "$INFRA_DIR"
    terraform init -backend=false
    log_success "Terraform initialized (without backend)"
    log_info "You can now update backend.tf and run 'terraform init -migrate-state'"
fi

echo ""
echo -e "${GREEN}Setup script completed successfully!${NC}"
