# Operational Excellence Runbooks

## Table of Contents
1. [Deployment Failure Runbook](#deployment-failure-runbook)
2. [Pipeline Failure Runbook](#pipeline-failure-runbook)
3. [Infrastructure Drift Detection](#infrastructure-drift-detection)
4. [Performance Degradation](#performance-degradation)
5. [Security Incident Response](#security-incident-response)

---

## Deployment Failure Runbook

### Purpose
Step-by-step procedures for handling deployment failures in the CI/CD pipeline.

### Scope
- CodePipeline failures
- CodeBuild failures
- Terraform deployment issues
- Lambda deployment problems

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed (version >= 1.3)
- Access to AWS Console
- SNS notifications configured

### Incident Response Process

#### 1. Initial Assessment (5 minutes)
```bash
# Check pipeline status
aws codepipeline get-pipeline-execution \
  --pipeline-name <pipeline-name> \
  --pipeline-execution-id <execution-id>

# Check recent CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/codebuild/"

# List recent failed builds
aws codebuild list-builds-for-project \
  --project-name <project-name> \
  --sort-order DESCENDING
```

#### 2. Identify Root Cause (10 minutes)

##### For Terraform Failures:
```bash
# Navigate to infrastructure directory
cd infra/

# Check Terraform state
terraform refresh
terraform plan

# Check for state lock issues
terraform force-unlock <lock-id>  # Use only if necessary

# Validate configuration
terraform validate
```

##### For Lambda Deployment Failures:
```bash
# Check Lambda function status
aws lambda get-function --function-name <function-name>

# Check recent Lambda errors
aws logs filter-log-events \
  --log-group-name "/aws/lambda/<function-name>" \
  --start-time $(date -d "1 hour ago" +%s)000 \
  --filter-pattern "ERROR"
```

##### For API Gateway Issues:
```bash
# Check API Gateway stages
aws apigateway get-stages --rest-api-id <api-id>

# Test API endpoint
curl -X POST <api-gateway-url> \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

#### 3. Resolution Steps

##### Terraform State Issues:
```bash
# Import missing resources
terraform import <resource_type>.<resource_name> <resource_id>

# Remove orphaned resources from state
terraform state rm <resource_address>

# Refresh state to match reality
terraform refresh
```

##### Lambda Function Issues:
```bash
# Rollback to previous version
aws lambda update-function-code \
  --function-name <function-name> \
  --s3-bucket <backup-bucket> \
  --s3-key <previous-version-key>

# Update environment variables if needed
aws lambda update-function-configuration \
  --function-name <function-name> \
  --environment Variables='{...}'
```

##### Database Connection Issues:
```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier <db-identifier>

# Test database connectivity
psql -h <rds-endpoint> -U <username> -d <database> -c "SELECT 1;"

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>
```

#### 4. Post-Incident Actions
1. Update monitoring alerts if gaps identified
2. Document lessons learned in incident log
3. Update runbook with new scenarios
4. Schedule post-mortem for major incidents
5. Review and update automation

### Escalation Matrix
- **Level 1**: DevOps Team Lead (immediate)
- **Level 2**: Engineering Manager (within 30 minutes)
- **Level 3**: CTO (for critical production issues)

---

## Pipeline Failure Runbook

### Common Pipeline Failures

#### Build Phase Failures
```bash
# Check build logs
aws codebuild batch-get-builds --ids <build-id>

# Common issues and solutions:
# 1. Dependency installation failures
#    - Check package.json/go.mod for version conflicts
#    - Verify network connectivity to package repositories

# 2. Test failures
#    - Run tests locally: npm test / go test ./...
#    - Check test environment variables

# 3. Linting failures
#    - Run linter locally: npm run lint / terraform fmt
#    - Fix formatting and code style issues
```

#### Deploy Phase Failures
```bash
# Check deployment logs
aws codepipeline get-pipeline-execution \
  --pipeline-name <pipeline-name> \
  --pipeline-execution-id <execution-id>

# Common deployment issues:
# 1. IAM permission errors
#    - Review CloudTrail logs for denied actions
#    - Update IAM policies as needed

# 2. Resource conflicts
#    - Check for naming conflicts
#    - Verify resource limits/quotas

# 3. Network connectivity issues
#    - Check VPC, subnet, and security group configurations
#    - Verify NAT Gateway and Internet Gateway connectivity
```

### Recovery Procedures

#### Rollback Deployment
```bash
# For Lambda functions
aws lambda update-function-code \
  --function-name <function-name> \
  --s3-bucket <artifacts-bucket> \
  --s3-key <previous-version>

# For S3 static assets
aws s3 sync s3://<backup-bucket>/<previous-version>/ s3://<website-bucket>/

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

---

## Infrastructure Drift Detection

### Automated Drift Detection
The infrastructure includes automated drift detection that runs daily:
- **Production**: 9:00 AM UTC
- **Development**: 6:00 PM UTC

### Manual Drift Check
```bash
# Run Terraform plan to detect drift
cd infra/
terraform plan -detailed-exitcode

# Exit codes:
# 0 = No changes
# 1 = Error
# 2 = Changes detected

# Generate drift report
terraform plan -out=drift.tfplan
terraform show -json drift.tfplan > drift-report.json
```

### Drift Resolution
```bash
# Option 1: Import changes to state
terraform import <resource_type>.<name> <resource_id>

# Option 2: Update configuration to match reality
# Edit .tf files to match current AWS configuration

# Option 3: Restore to desired state
terraform apply

# Option 4: Accept changes and update state
terraform refresh
```

---

## Performance Degradation

### Performance Monitoring
Monitor these key metrics:
- Lambda function duration and errors
- API Gateway latency and error rates
- CloudFront cache hit ratio
- RDS CPU utilization and connections

### Performance Issue Resolution

#### High Lambda Duration
```bash
# Check Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=<function-name> \
  --start-time <start-time> \
  --end-time <end-time> \
  --period 300 \
  --statistics Average,Maximum

# Increase memory allocation if needed
aws lambda update-function-configuration \
  --function-name <function-name> \
  --memory-size 512
```

#### API Gateway High Latency
```bash
# Enable detailed monitoring
aws apigateway put-method-response \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method POST \
  --status-code 200

# Check cache configuration
aws apigateway get-stage \
  --rest-api-id <api-id> \
  --stage-name <stage-name>
```

#### Database Performance Issues
```bash
# Check RDS performance metrics
aws rds describe-db-instances --db-instance-identifier <db-id>

# Enable Performance Insights if not already enabled
aws rds modify-db-instance \
  --db-instance-identifier <db-id> \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

---

## Security Incident Response

### Incident Classification
- **Critical**: Data breach, unauthorized access to production
- **High**: Security control bypass, privilege escalation
- **Medium**: Configuration drift, policy violations
- **Low**: Security scan findings, documentation issues

### Immediate Response Steps

#### 1. Containment (0-15 minutes)
```bash
# Disable compromised user accounts
aws iam update-user --user-name <user> --no-password-reset-required

# Revoke active sessions
aws iam delete-access-key --user-name <user> --access-key-id <key-id>

# Block suspicious IP addresses (if using WAF)
aws wafv2 update-ip-set \
  --scope CLOUDFRONT \
  --id <ip-set-id> \
  --addresses <malicious-ip>/32
```

#### 2. Investigation (15-60 minutes)
```bash
# Check CloudTrail logs
aws logs filter-log-events \
  --log-group-name CloudTrail/... \
  --start-time $(date -d "24 hours ago" +%s)000 \
  --filter-pattern "ERROR"

# Review access logs
aws logs filter-log-events \
  --log-group-name /aws/apigateway/... \
  --filter-pattern "[timestamp, request_id, ip != \"127.0.0.1\"]"
```

#### 3. Recovery (1-4 hours)
```bash
# Rotate compromised credentials
aws secretsmanager rotate-secret --secret-id <secret-arn>

# Update security groups
aws ec2 revoke-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Force re-deployment of affected services
aws codepipeline start-pipeline-execution \
  --name <pipeline-name>
```

### Contact Information
- **Security Team**: security@company.com
- **On-Call Engineer**: +1-XXX-XXX-XXXX
- **Incident Commander**: incident-commander@company.com

---

## Related Documentation
- [Architecture Documentation](../docs/architecture.md)
- [Monitoring Guide](./monitoring.md)
- [Security Procedures](./security.md)
- [WAF Report](../WAF-Report.md)