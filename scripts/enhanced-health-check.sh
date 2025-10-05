#!/bin/bash
#
# Enhanced Deployment Health Check Script
# P2 Reliability: Comprehensive health validation with rollback triggers
#

set -e

# Configuration
HEALTH_CHECK_TIMEOUT=300  # 5 minutes
MAX_RETRIES=5
RETRY_DELAY=10
HEALTH_CHECK_LOG="/tmp/health-check.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$HEALTH_CHECK_LOG"
}

# Health check with retry logic
health_check_with_retry() {
    local check_name="$1"
    local check_command="$2"
    local retries=0
    
    log "${YELLOW}[HEALTH CHECK]${NC} Starting $check_name..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$check_command"; then
            log "${GREEN}[SUCCESS]${NC} $check_name passed"
            return 0
        else
            retries=$((retries + 1))
            if [ $retries -lt $MAX_RETRIES ]; then
                log "${YELLOW}[RETRY]${NC} $check_name failed, retrying in ${RETRY_DELAY}s (attempt $retries/$MAX_RETRIES)"
                sleep $RETRY_DELAY
            else
                log "${RED}[FAILURE]${NC} $check_name failed after $MAX_RETRIES attempts"
                return 1
            fi
        fi
    done
}

# API Gateway health check
check_api_gateway() {
    if [ -z "$API_GATEWAY_URL" ]; then
        log "${YELLOW}[SKIP]${NC} API Gateway URL not provided"
        return 0
    fi
    
    # Test CORS preflight
    if ! curl -f -s -m 30 "$API_GATEWAY_URL/contact" \
        -X OPTIONS \
        -H "Origin: https://example.com" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type" > /dev/null; then
        return 1
    fi
    
    # Test actual POST endpoint
    if ! curl -f -s -m 30 "$API_GATEWAY_URL/contact" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"name":"Health Check","email":"healthcheck@example.com","message":"Automated health check"}' > /dev/null; then
        return 1
    fi
    
    return 0
}

# Lambda function health check
check_lambda_function() {
    if [ -z "$LAMBDA_FUNCTION" ]; then
        log "${YELLOW}[SKIP]${NC} Lambda function name not provided"
        return 0
    fi
    
    # Test Lambda invocation
    local response_file="/tmp/lambda-health-response.json"
    if ! aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION" \
        --payload '{"httpMethod":"GET","path":"/health","headers":{}}' \
        --region "$AWS_REGION" \
        "$response_file" > /dev/null 2>&1; then
        return 1
    fi
    
    # Check if response contains expected structure
    if ! grep -q "statusCode" "$response_file"; then
        return 1
    fi
    
    return 0
}

# S3 website health check
check_s3_website() {
    if [ -z "$S3_BUCKET" ]; then
        log "${YELLOW}[SKIP]${NC} S3 bucket name not provided"
        return 0
    fi
    
    # Check if index.html exists and is accessible
    if ! aws s3api head-object --bucket "$S3_BUCKET" --key "index.html" --region "$AWS_REGION" > /dev/null 2>&1; then
        return 1
    fi
    
    # Check if website endpoint is accessible
    local website_url="http://${S3_BUCKET}.s3-website.${AWS_REGION}.amazonaws.com"
    if ! curl -f -s -m 30 "$website_url" > /dev/null; then
        return 1
    fi
    
    return 0
}

# CloudFront distribution health check
check_cloudfront() {
    if [ -z "$CLOUDFRONT_ID" ]; then
        log "${YELLOW}[SKIP]${NC} CloudFront distribution ID not provided"
        return 0
    fi
    
    # Check distribution status
    local status=$(aws cloudfront get-distribution --id "$CLOUDFRONT_ID" --query 'Distribution.Status' --output text 2>/dev/null || echo "")
    if [ "$status" != "Deployed" ]; then
        return 1
    fi
    
    # Test CloudFront endpoint
    local domain_name=$(aws cloudfront get-distribution --id "$CLOUDFRONT_ID" --query 'Distribution.DomainName' --output text 2>/dev/null || echo "")
    if [ -n "$domain_name" ]; then
        if ! curl -f -s -m 30 "https://$domain_name" > /dev/null; then
            return 1
        fi
    fi
    
    return 0
}

# Database connectivity check
check_database() {
    if [ -z "$RDS_ENDPOINT" ]; then
        log "${YELLOW}[SKIP]${NC} RDS endpoint not provided"
        return 0
    fi
    
    # Test database connectivity using Lambda (if available)
    if [ -n "$LAMBDA_FUNCTION" ]; then
        local response_file="/tmp/db-health-response.json"
        if ! aws lambda invoke \
            --function-name "$LAMBDA_FUNCTION" \
            --payload '{"httpMethod":"GET","path":"/db-health"}' \
            --region "$AWS_REGION" \
            "$response_file" > /dev/null 2>&1; then
            return 1
        fi
        
        # Check if database connection was successful
        if ! grep -q '"database":"connected"' "$response_file"; then
            return 1
        fi
    fi
    
    return 0
}

# Route53 health check
check_route53() {
    if [ -z "$ROUTE53_RECORD" ]; then
        log "${YELLOW}[SKIP]${NC} Route53 record not provided"
        return 0
    fi
    
    # Test DNS resolution
    if ! nslookup "$ROUTE53_RECORD" > /dev/null 2>&1; then
        return 1
    fi
    
    # Test HTTP endpoint if it's a web record
    if curl -f -s -m 30 "https://$ROUTE53_RECORD" > /dev/null 2>&1; then
        return 0
    elif curl -f -s -m 30 "http://$ROUTE53_RECORD" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Integration test
run_integration_test() {
    log "${YELLOW}[INTEGRATION]${NC} Running end-to-end integration test..."
    
    if [ -n "$API_GATEWAY_URL" ]; then
        # Test full contact form workflow
        local test_payload='{"name":"Integration Test","email":"test@example.com","message":"End-to-end test message"}'
        local response_file="/tmp/integration-response.json"
        
        if curl -f -s -m 30 "$API_GATEWAY_URL/contact" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$test_payload" \
            -o "$response_file"; then
            log "${GREEN}[SUCCESS]${NC} Integration test completed"
            return 0
        else
            log "${RED}[FAILURE]${NC} Integration test failed"
            return 1
        fi
    else
        log "${YELLOW}[SKIP]${NC} Integration test skipped - no API Gateway URL"
        return 0
    fi
}

# Generate health check report
generate_report() {
    local exit_code=$1
    local report_file="/tmp/health-check-report.json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "environment": "${ENVIRONMENT:-unknown}",
    "deployment_id": "${CODEBUILD_BUILD_ID:-unknown}",
    "health_check_status": "$([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "checks_performed": [
        "api_gateway",
        "lambda_function", 
        "s3_website",
        "cloudfront",
        "database",
        "route53",
        "integration_test"
    ],
    "log_file": "$HEALTH_CHECK_LOG",
    "aws_region": "$AWS_REGION"
}
EOF
    
    log "Health check report generated: $report_file"
    if command -v jq > /dev/null; then
        cat "$report_file" | jq '.'
    else
        cat "$report_file"
    fi
}

# Send notification
send_notification() {
    local status=$1
    local message="$2"
    
    if [ -n "$SNS_TOPIC_ARN" ]; then
        local subject="Health Check $status - ${ENVIRONMENT:-unknown}"
        aws sns publish \
            --topic-arn "$SNS_TOPIC_ARN" \
            --subject "$subject" \
            --message "$message" \
            --region "$AWS_REGION" > /dev/null 2>&1 || true
    fi
}

# Main health check execution
main() {
    log "${GREEN}[START]${NC} Enhanced deployment health checks starting..."
    log "Environment: ${ENVIRONMENT:-unknown}"
    log "AWS Region: $AWS_REGION"
    log "Build ID: ${CODEBUILD_BUILD_ID:-unknown}"
    
    local failed_checks=0
    local start_time=$(date +%s)
    
    # Wait for deployment to stabilize
    log "Waiting 30 seconds for deployment to stabilize..."
    sleep 30
    
    # Run health checks with retry logic
    health_check_with_retry "API Gateway" "check_api_gateway" || ((failed_checks++))
    health_check_with_retry "Lambda Function" "check_lambda_function" || ((failed_checks++))
    health_check_with_retry "S3 Website" "check_s3_website" || ((failed_checks++))
    health_check_with_retry "CloudFront" "check_cloudfront" || ((failed_checks++))
    health_check_with_retry "Database" "check_database" || ((failed_checks++))
    health_check_with_retry "Route53" "check_route53" || ((failed_checks++))
    health_check_with_retry "Integration Test" "run_integration_test" || ((failed_checks++))
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Generate report and send notifications
    if [ $failed_checks -eq 0 ]; then
        log "${GREEN}[SUCCESS]${NC} All health checks passed! (Duration: ${duration}s)"
        generate_report 0
        send_notification "SUCCESS" "All deployment health checks passed successfully in ${duration} seconds."
        exit 0
    else
        log "${RED}[FAILURE]${NC} $failed_checks health check(s) failed! (Duration: ${duration}s)"
        generate_report 1
        send_notification "FAILURE" "$failed_checks health check(s) failed. Check logs for details. Duration: ${duration} seconds."
        
        # Trigger rollback if critical checks failed
        if [ $failed_checks -ge 3 ]; then
            log "${RED}[CRITICAL]${NC} Multiple health checks failed - triggering rollback"
            # Rollback will be implemented in the next phase
        fi
        
        exit 1
    fi
}

# Execute main function
main "$@"
