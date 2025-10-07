# Terraform Modules

This directory contains reusable Terraform modules for the Project3 infrastructure. Each module is designed to be self-contained and follows Terraform best practices.

## Module Structure

### s3
Manages S3 buckets for website hosting and CodePipeline artifacts.
- Website bucket with CloudFront OAI integration
- Artifacts bucket with versioning enabled
- Lifecycle policies for cost optimization

### cloudfront
Manages CloudFront distribution for CDN functionality.
- Origin Access Identity (OAI) for secure S3 access
- Optimized caching behavior
- HTTPS redirect configuration

### api-gateway
Manages API Gateway REST API for the contact form.
- REST API with CORS support
- Lambda integration
- Custom error responses with CORS headers

### lambda
Manages Lambda function for contact form processing.
- IAM role and policies
- Environment variables for database connection
- API Gateway permissions

### rds
Manages PostgreSQL RDS instance.
- Security group configuration
- Free tier optimized settings
- Public accessibility for demo purposes

### iam
Manages IAM roles and policies for CodePipeline and CodeBuild.
- CodePipeline service role
- CodeBuild service role
- Comprehensive permissions for CI/CD operations

### codepipeline
Manages CodePipeline and CodeBuild projects.
- Infrastructure deployment pipeline
- Web application deployment pipeline
- GitHub integration via CodeStar connections

### monitoring
Manages CloudWatch monitoring and cost protection.
- Billing alarms
- Cost threshold monitoring

## Usage

Each module follows the standard Terraform module structure:
- `main.tf` - Main resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## Best Practices

1. **Modularity**: Each module is focused on a specific service or functionality
2. **Reusability**: Modules can be reused across different environments
3. **Encapsulation**: Internal resources are not exposed unless necessary
4. **Consistency**: All modules follow the same structure and naming conventions
5. **Documentation**: Each module is well-documented with descriptions
6. **Security**: Sensitive variables are marked appropriately
7. **Tags**: Consistent tagging strategy across all resources
