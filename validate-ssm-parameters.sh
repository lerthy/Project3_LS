#!/bin/bash

# Script to validate all required SSM parameters for Project3
# This script checks if all necessary SSM parameters exist and have valid values

set -e

# Configuration
REGION="us-east-1"
REQUIRED_PARAMS=(
    "/project3/db/username"
    "/project3/db/password"
    "/project3/db/name"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Validating SSM Parameters for Project3...${NC}"
echo -e "${BLUE}Region: $REGION${NC}"
echo ""

# Function to check if parameter exists
check_parameter() {
    local param_name=$1
    local param_type=$2
    
    echo -n "Checking $param_name... "
    
    # Try to get the parameter
    if aws ssm get-parameter --name "$param_name" --region "$REGION" --with-decryption >/dev/null 2>&1; then
        # Get parameter value (only show first few chars for security)
        local value=$(aws ssm get-parameter --name "$param_name" --region "$REGION" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)
        
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            local display_value
            if [[ "$param_name" == *"password"* ]]; then
                display_value="***$(echo "$value" | tail -c 4)"
            else
                display_value="$value"
            fi
            echo -e "${GREEN}✅ EXISTS${NC} (Value: $display_value)"
            return 0
        else
            echo -e "${RED}❌ EMPTY${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ NOT FOUND${NC}"
        return 1
    fi
}

# Function to create missing parameter
create_parameter() {
    local param_name=$1
    local param_description=$2
    local param_type="String"
    
    # Use SecureString for password
    if [[ "$param_name" == *"password"* ]]; then
        param_type="SecureString"
    fi
    
    echo -e "${YELLOW}Creating parameter: $param_name${NC}"
    
    case "$param_name" in
        "/project3/db/username")
            local default_value="appuser"
            ;;
        "/project3/db/name")
            local default_value="contacts"
            ;;
        "/project3/db/password")
            # Generate a secure password
            local default_value=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)
            echo -e "${YELLOW}Generated secure password for database${NC}"
            ;;
        *)
            read -p "Enter value for $param_name: " default_value
            ;;
    esac
    
    # Create the parameter
    aws ssm put-parameter \
        --name "$param_name" \
        --description "$param_description" \
        --value "$default_value" \
        --type "$param_type" \
        --region "$REGION" \
        --overwrite >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Created successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create${NC}"
        return 1
    fi
}

# Main validation logic
echo -e "${BLUE}📋 Required Parameters:${NC}"
for param in "${REQUIRED_PARAMS[@]}"; do
    echo "  - $param"
done
echo ""

missing_params=()
validation_passed=true

# Check each required parameter
for param in "${REQUIRED_PARAMS[@]}"; do
    if ! check_parameter "$param"; then
        missing_params+=("$param")
        validation_passed=false
    fi
done

echo ""

# Handle missing parameters
if [ ${#missing_params[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Missing Parameters Detected!${NC}"
    echo ""
    echo -e "${BLUE}Missing parameters:${NC}"
    for param in "${missing_params[@]}"; do
        echo "  - $param"
    done
    echo ""
    
    read -p "Would you like to create the missing parameters automatically? (y/N): " create_choice
    
    if [[ $create_choice =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}🚀 Creating missing parameters...${NC}"
        
        for param in "${missing_params[@]}"; do
            case "$param" in
                "/project3/db/username")
                    create_parameter "$param" "Database username for Project3 application"
                    ;;
                "/project3/db/name")
                    create_parameter "$param" "Database name for Project3 application"
                    ;;
                "/project3/db/password")
                    create_parameter "$param" "Database password for Project3 application (SecureString)"
                    ;;
            esac
        done
        
        echo ""
        echo -e "${BLUE}🔄 Re-validating parameters...${NC}"
        echo ""
        
        # Re-check all parameters
        validation_passed=true
        for param in "${REQUIRED_PARAMS[@]}"; do
            if ! check_parameter "$param"; then
                validation_passed=false
            fi
        done
    else
        echo -e "${YELLOW}Skipping parameter creation.${NC}"
        echo ""
        echo -e "${BLUE}💡 To create parameters manually:${NC}"
        for param in "${missing_params[@]}"; do
            if [[ "$param" == *"password"* ]]; then
                echo "aws ssm put-parameter --name '$param' --value 'YOUR_SECURE_PASSWORD' --type SecureString --region $REGION"
            else
                echo "aws ssm put-parameter --name '$param' --value 'YOUR_VALUE' --type String --region $REGION"
            fi
        done
    fi
fi

echo ""

# Final validation result
if [ "$validation_passed" = true ]; then
    echo -e "${GREEN}🎉 SUCCESS: All SSM parameters are configured correctly!${NC}"
    echo ""
    echo -e "${BLUE}📋 Summary:${NC}"
    echo -e "${GREEN}✅ Database Username: /project3/db/username${NC}"
    echo -e "${GREEN}✅ Database Password: /project3/db/password (SecureString)${NC}"
    echo -e "${GREEN}✅ Database Name: /project3/db/name${NC}"
    echo ""
    echo -e "${GREEN}🚀 Ready for Terraform deployment!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. cd infra"
    echo "2. terraform init"
    echo "3. terraform plan"
    echo "4. terraform apply"
    exit 0
else
    echo -e "${RED}❌ FAILED: Some SSM parameters are missing or invalid${NC}"
    echo ""
    echo -e "${YELLOW}Please fix the issues above before proceeding with Terraform deployment.${NC}"
    exit 1
fi
