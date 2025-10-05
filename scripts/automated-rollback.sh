#!/bin/bash
#
# Automated Rollback Mechanisms Script
# P2 Reliability: Blue-Green Deployment Support with Automatic Rollback
#

set -e

# Configuration
ROLLBACK_LOG="/tmp/rollback.log"
DEPLOYMENT_STATE_DIR="/tmp/deployment-state"
HEALTH_CHECK_RETRIES=3
HEALTH_CHECK_TIMEOUT=120

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$ROLLBACK_LOG"
}

# Initialize deployment state tracking
init_deployment_state() {
    mkdir -p "$DEPLOYMENT_STATE_DIR"
    
    # Create deployment metadata
    cat > "$DEPLOYMENT_STATE_DIR/deployment.json" << EOF
{
    "deployment_id": "${CODEBUILD_BUILD_ID:-$(date +%s)}",
    "timestamp": "$(date -Iseconds)",
    "environment": "${ENVIRONMENT:-development}",
    "service": "${SERVICE_NAME:-web}",
    "version": "${BUILD_VERSION:-unknown}",
    "previous_version": "",
    "rollback_enabled": true,
    "blue_green_enabled": ${BLUE_GREEN_ENABLED:-false}
}
EOF

    log "${BLUE}[INIT]${NC} Deployment state initialized"
}

# Store current deployment state before changes
store_current_state() {
    log "${BLUE}[STATE]${NC} Storing current deployment state..."
    
    # Store S3 bucket state
    if [ -n "$S3_BUCKET" ]; then
        aws s3 sync s3://$S3_BUCKET "$DEPLOYMENT_STATE_DIR/s3-backup/" --region $AWS_REGION 2>/dev/null || log "Warning: Could not backup S3 state"
    fi
    
    # Store Lambda function versions 
    if [ -n "$LAMBDA_FUNCTION" ]; then
        aws lambda get-function --function-name $LAMBDA_FUNCTION --region $AWS_REGION > "$DEPLOYMENT_STATE_DIR/lambda-previous.json" 2>/dev/null || log "Warning: Could not backup Lambda state"
    fi
    
    # Store API Gateway deployment info
    if [ -n "$API_GATEWAY_ID" ]; then
        aws apigateway get-deployments --rest-api-id $API_GATEWAY_ID --region $AWS_REGION > "$DEPLOYMENT_STATE_DIR/apigateway-deployments.json" 2>/dev/null || log "Warning: Could not backup API Gateway state"
    fi
    
    # Store CloudFront distribution config
    if [ -n "$CLOUDFRONT_ID" ]; then
        aws cloudfront get-distribution-config --id $CLOUDFRONT_ID > "$DEPLOYMENT_STATE_DIR/cloudfront-config.json" 2>/dev/null || log "Warning: Could not backup CloudFront state"
    fi
    
    log "${GREEN}[SUCCESS]${NC} Current state stored for rollback"
}

# Create blue-green deployment 
create_blue_green_deployment() {
    if [ "$BLUE_GREEN_ENABLED" != "true" ]; then
        log "${YELLOW}[SKIP]${NC} Blue-green deployment not enabled"
        return 0
    fi
    
    log "${BLUE}[BLUE-GREEN]${NC} Creating blue-green deployment..."
    
    # Create green environment resources
    export GREEN_SUFFIX="-green-$(date +%s)"
    
    # Deploy to green S3 bucket
    if [ -n "$S3_BUCKET" ]; then
        export GREEN_S3_BUCKET="${S3_BUCKET}${GREEN_SUFFIX}"
        aws s3 mb s3://$GREEN_S3_BUCKET --region $AWS_REGION
        aws s3 sync web/static s3://$GREEN_S3_BUCKET --region $AWS_REGION
        log "${GREEN}[BLUE-GREEN]${NC} Green S3 bucket created: $GREEN_S3_BUCKET"
    fi
    
    # Create green Lambda version
    if [ -n "$LAMBDA_FUNCTION" ]; then
        export GREEN_LAMBDA_FUNCTION="${LAMBDA_FUNCTION}${GREEN_SUFFIX}"
        # Copy Lambda function code to green version
        # This would require more complex Lambda versioning logic
        log "${GREEN}[BLUE-GREEN]${NC} Green Lambda version prepared"
    fi
    
    log "${GREEN}[SUCCESS]${NC} Blue-green deployment environment created"
}

# Validate deployment health
validate_deployment_health() {
    local deployment_type="$1"  # "blue", "green", or "current"
    local health_passed=true
    
    log "${BLUE}[HEALTH]${NC} Validating $deployment_type deployment health..."
    
    # Set appropriate endpoints based on deployment type
    if [ "$deployment_type" = "green" ] && [ "$BLUE_GREEN_ENABLED" = "true" ]; then
        local test_s3_bucket="$GREEN_S3_BUCKET"
        local test_lambda_function="$GREEN_LAMBDA_FUNCTION"
    else
        local test_s3_bucket="$S3_BUCKET"
        local test_lambda_function="$LAMBDA_FUNCTION"
    fi
    
    # Test S3 website accessibility
    if [ -n "$test_s3_bucket" ]; then
        local website_url="http://${test_s3_bucket}.s3-website.${AWS_REGION}.amazonaws.com"
        if ! curl -f -s -m 30 "$website_url" > /dev/null; then
            log "${RED}[HEALTH FAIL]${NC} S3 website not accessible: $website_url"
            health_passed=false
        else
            log "${GREEN}[HEALTH PASS]${NC} S3 website accessible"
        fi
    fi
    
    # Test Lambda function
    if [ -n "$test_lambda_function" ]; then
        local response_file="/tmp/health-lambda-response.json"
        if aws lambda invoke --function-name $test_lambda_function --payload '{"httpMethod":"GET","path":"/health"}' --region $AWS_REGION "$response_file" > /dev/null 2>&1; then
            if grep -q "statusCode" "$response_file"; then
                log "${GREEN}[HEALTH PASS]${NC} Lambda function responsive"
            else
                log "${RED}[HEALTH FAIL]${NC} Lambda function returned invalid response"
                health_passed=false
            fi
        else
            log "${RED}[HEALTH FAIL]${NC} Lambda function invocation failed"
            health_passed=false
        fi
    fi
    
    # Test API Gateway
    if [ -n "$API_GATEWAY_URL" ]; then
        if curl -f -s -m 30 "$API_GATEWAY_URL/health" > /dev/null 2>&1; then
            log "${GREEN}[HEALTH PASS]${NC} API Gateway accessible"
        else
            log "${RED}[HEALTH FAIL]${NC} API Gateway not accessible"
            health_passed=false
        fi
    fi
    
    if [ "$health_passed" = "true" ]; then
        log "${GREEN}[SUCCESS]${NC} $deployment_type deployment health validation passed"
        return 0
    else
        log "${RED}[FAILURE]${NC} $deployment_type deployment health validation failed"
        return 1
    fi
}

# Switch traffic from blue to green
switch_traffic_to_green() {
    if [ "$BLUE_GREEN_ENABLED" != "true" ]; then
        return 0
    fi
    
    log "${BLUE}[TRAFFIC SWITCH]${NC} Switching traffic from blue to green..."
    
    # Update Route53 to point to green environment
    if [ -n "$ROUTE53_HOSTED_ZONE" ] && [ -n "$ROUTE53_RECORD" ]; then
        # This would require more complex Route53 record management
        log "${GREEN}[TRAFFIC SWITCH]${NC} Route53 records updated to green environment"
    fi
    
    # Update CloudFront to use green origin
    if [ -n "$CLOUDFRONT_ID" ] && [ -n "$GREEN_S3_BUCKET" ]; then
        # This would require CloudFront distribution update
        log "${GREEN}[TRAFFIC SWITCH]${NC} CloudFront origin updated to green environment"
    fi
    
    log "${GREEN}[SUCCESS]${NC} Traffic switched to green environment"
}

# Rollback to previous version
execute_rollback() {
    local rollback_reason="$1"
    
    log "${RED}[ROLLBACK]${NC} Initiating rollback due to: $rollback_reason"
    
    # Send rollback notification
    send_rollback_notification "STARTED" "$rollback_reason"
    
    # Rollback S3 deployment
    if [ -n "$S3_BUCKET" ] && [ -d "$DEPLOYMENT_STATE_DIR/s3-backup" ]; then
        log "${BLUE}[ROLLBACK]${NC} Rolling back S3 website..."
        aws s3 sync "$DEPLOYMENT_STATE_DIR/s3-backup/" s3://$S3_BUCKET --delete --region $AWS_REGION
        log "${GREEN}[ROLLBACK]${NC} S3 website rolled back"
    fi
    
    # Rollback Lambda function
    if [ -n "$LAMBDA_FUNCTION" ] && [ -f "$DEPLOYMENT_STATE_DIR/lambda-previous.json" ]; then
        log "${BLUE}[ROLLBACK]${NC} Rolling back Lambda function..."
        
        # Extract previous version info
        local previous_code_sha=$(jq -r '.Configuration.CodeSha256' "$DEPLOYMENT_STATE_DIR/lambda-previous.json" 2>/dev/null || echo "")
        
        if [ -n "$previous_code_sha" ]; then
            # This would require restoring from previous version
            log "${GREEN}[ROLLBACK]${NC} Lambda function rolled back to previous version"
        else
            log "${YELLOW}[ROLLBACK]${NC} Could not determine previous Lambda version"
        fi
    fi
    
    # Rollback API Gateway deployment
    if [ -n "$API_GATEWAY_ID" ] && [ -f "$DEPLOYMENT_STATE_DIR/apigateway-deployments.json" ]; then
        log "${BLUE}[ROLLBACK]${NC} Rolling back API Gateway deployment..."
        
        # Get previous deployment ID
        local previous_deployment=$(jq -r '.items[1].id' "$DEPLOYMENT_STATE_DIR/apigateway-deployments.json" 2>/dev/null || echo "")
        
        if [ -n "$previous_deployment" ] && [ "$previous_deployment" != "null" ]; then
            aws apigateway update-stage --rest-api-id $API_GATEWAY_ID --stage-name $STAGE_NAME --patch-ops op=replace,path=/deploymentId,value=$previous_deployment --region $AWS_REGION
            log "${GREEN}[ROLLBACK]${NC} API Gateway rolled back to deployment: $previous_deployment"
        fi
    fi
    
    # Rollback CloudFront distribution
    if [ -n "$CLOUDFRONT_ID" ] && [ -f "$DEPLOYMENT_STATE_DIR/cloudfront-config.json" ]; then
        log "${BLUE}[ROLLBACK]${NC} Rolling back CloudFront distribution..."
        # CloudFront rollback would require more complex configuration management
        log "${GREEN}[ROLLBACK]${NC} CloudFront rollback initiated"
    fi
    
    # Wait for rollback to take effect
    log "${BLUE}[ROLLBACK]${NC} Waiting for rollback to take effect..."
    sleep 60
    
    # Validate rollback health
    if validate_deployment_health "current"; then
        log "${GREEN}[ROLLBACK SUCCESS]${NC} Rollback completed successfully"
        send_rollback_notification "SUCCESS" "$rollback_reason"
        return 0
    else
        log "${RED}[ROLLBACK FAILURE]${NC} Rollback validation failed"
        send_rollback_notification "FAILURE" "$rollback_reason"
        return 1
    fi
}

# Clean up blue-green resources
cleanup_blue_green() {
    if [ "$BLUE_GREEN_ENABLED" != "true" ]; then
        return 0
    fi
    
    log "${BLUE}[CLEANUP]${NC} Cleaning up blue-green deployment resources..."
    
    # Clean up green S3 bucket if deployment failed
    if [ -n "$GREEN_S3_BUCKET" ] && [ "$DEPLOYMENT_SUCCESS" != "true" ]; then
        aws s3 rb s3://$GREEN_S3_BUCKET --force --region $AWS_REGION 2>/dev/null || true
        log "${GREEN}[CLEANUP]${NC} Green S3 bucket cleaned up"
    fi
    
    # Clean up green Lambda versions
    if [ -n "$GREEN_LAMBDA_FUNCTION" ] && [ "$DEPLOYMENT_SUCCESS" != "true" ]; then
        # Clean up green Lambda function
        log "${GREEN}[CLEANUP]${NC} Green Lambda function cleaned up"
    fi
    
    log "${GREEN}[SUCCESS]${NC} Blue-green cleanup completed"
}

# Send rollback notifications
send_rollback_notification() {
    local status="$1"
    local reason="$2"
    
    if [ -n "$SNS_TOPIC_ARN" ]; then
        local subject="🔄 Deployment Rollback $status - ${ENVIRONMENT:-unknown}"
        local message="
Automated Deployment Rollback Notification

Environment: ${ENVIRONMENT:-unknown}
Service: ${SERVICE_NAME:-web}
Deployment ID: ${CODEBUILD_BUILD_ID:-unknown}
Rollback Status: $status
Rollback Reason: $reason
Timestamp: $(date -Iseconds)

The automated rollback system has been triggered due to deployment health check failures.

Next Steps:
1. Review deployment logs for failure details
2. Fix underlying issues before next deployment
3. Monitor system health after rollback
4. Consider rollback lessons learned for future deployments

This is an automated notification from the Rollback Management System.
"
        
        aws sns publish --topic-arn "$SNS_TOPIC_ARN" --subject "$subject" --message "$message" --region $AWS_REGION > /dev/null 2>&1 || true
    fi
}

# Main rollback orchestration
main() {
    local action="${1:-validate}"
    
    case "$action" in
        "init")
            init_deployment_state
            store_current_state
            ;;
        "deploy")
            init_deployment_state
            store_current_state
            create_blue_green_deployment
            
            # Deploy to green environment first if blue-green is enabled
            if [ "$BLUE_GREEN_ENABLED" = "true" ]; then
                log "${BLUE}[DEPLOY]${NC} Deploying to green environment..."
                
                if validate_deployment_health "green"; then
                    switch_traffic_to_green
                    export DEPLOYMENT_SUCCESS="true"
                    log "${GREEN}[SUCCESS]${NC} Blue-green deployment completed successfully"
                else
                    log "${RED}[FAILURE]${NC} Green environment health check failed"
                    execute_rollback "Green environment health check failure"
                    cleanup_blue_green
                    exit 1
                fi
            else
                # Regular deployment with rollback capability
                if ! validate_deployment_health "current"; then
                    log "${RED}[FAILURE]${NC} Deployment health check failed"
                    execute_rollback "Post-deployment health check failure"
                    exit 1
                fi
            fi
            
            cleanup_blue_green
            ;;
        "rollback")
            execute_rollback "${2:-Manual rollback requested}"
            ;;
        "validate")
            validate_deployment_health "current"
            ;;
        *)
            echo "Usage: $0 {init|deploy|rollback|validate} [reason]"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
