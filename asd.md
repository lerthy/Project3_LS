# Well-Architected Framework (WAF) Review – DevOps CI/CD Project

## Instructions
1. Baseline: Briefly describe your existing setup (tools, repos, target environment, runtime). 15 sentences max.
2. Per pillar: Fill the sections below:
   - Current state
   - Gaps
   - TF improvements
   - Evidence
3. Terraform: Implement or reference TF changes that realize improvements.
4. Validation: Link evidence (TF code lines, logs, screenshots) where possible.

---

## Baseline
- Tools: AWS (S3, CloudFront, API Gateway, Lambda, RDS, CloudWatch), CodePipeline, CodeBuild, SSM Parameter Store, Terraform, Go (tests), Node.js 18 (web, lambda), ESLint, Stylelint, Vitest.
- Repositories/Monorepo: Single repo with `infra/` (Terraform), `cicd/` (pipelines), and `web/` (static site + lambda).
- Environments (dev/stage/prod): Single "development" environment tags; pipelines branch-driven (`develop`).
- Cloud provider/region(s): AWS `us-east-1` (set in buildspecs and Terraform backend).
- Runtimes (frontend/backend/lambdas/DB): Static web (HTML/CSS/JS), Node.js Lambda for contact form, PostgreSQL RDS, API Gateway REST API.
- CI/CD (build, test, deploy): Two CodePipelines (infra & web) with CodeBuild steps; linting and tests in `buildspec-*.yml`; S3 deploy, Lambda update, CloudFront invalidation.
- IaC (Terraform versions/modules): Terraform >=1.3 (backend S3/DynamoDB); modules for `s3`, `cloudfront`, `rds`, `lambda`, `api-gateway`, `iam`, `monitoring`, and `cicd`.
- Observability (logs/metrics/tracing): CloudWatch logs for Lambda via `AWSLambdaBasicExecutionRole`; CloudWatch billing alarm; CodeBuild/CodePipeline logs.
- Networking (VPCs/subnets): Uses default VPC only for RDS security group; Lambda not in VPC; API Gateway public; CloudFront over S3 OAI.
- Security (IAM/KMS/secrets mgmt): IAM roles for CodeBuild/CodePipeline/Lambda; SSM parameters for DB creds; S3 public access blocked; CloudFront OAI for S3.
- Data stores (RDS/S3/others): RDS Postgres instance; S3 website and artifacts buckets; SSM Parameter Store for config.
- Edge/CDN: CloudFront distribution with HTTPS redirect; OAI restricting S3.
- Key SLIs/SLOs: Not explicitly defined in repo.

---

## 1) Operational Excellence
### Current state
- CI/CD via two CodePipelines with CodeBuild projects; infra pipeline runs fmt/validate/plan/apply; web pipeline runs lint/tests and deploys static site + Lambda + CF invalidation.
- Common tagging in Terraform locals; basic Go test scaffold present for infra.

### Gaps
- No alarms/notifications on pipeline or build failures; no manual approval gates.
- Limited automated tests (Terratest skipped); no runbooks.

### TF improvements
- Add CloudWatch alarms + SNS topics for CodeBuild/CodePipeline failures; add manual approval stage in pipelines.
- Add Terratest stage and enforce on PRs; expand tagging (owner, cost-center, service, environment).

### Evidence
- `cicd/main.tf` (CodePipeline, CodeBuild stages)
- `buildspec-infra.yml`, `buildspec-web.yml` (lint/test/plan/apply/deploy)
- `infra/main.tf` locals `common_tags`
- `infra/tests/infra_integration_test.go`

---

## 2) Security
### Current state
- S3 website bucket blocks public access; CloudFront OAI policy restricts reads.
- Lambda uses basic execution role and scoped SSM read policy for DB params.
- API Gateway POST/OPTIONS without auth; RDS SG allows 0.0.0.0/0 to 5432 (demo).
- Terraform remote state in S3 with DynamoDB lock and encryption.

### Gaps
- RDS publicly accessible SG; Lambda not in VPC; no KMS CMKs for S3/RDS.
- API lacks authentication/authorization and WAF; CodeBuild IAM policies broad with wildcards.
- No secret rotation; SSM path not scoped to environment.

### TF improvements
- Place RDS in private subnets and restrict SG to Lambda/VPC CIDR; attach KMS CMK to RDS and S3.
- Put Lambda in VPC with least-priv SG; add Secrets Manager for credentials with rotation; scope SSM paths by env.
- Add API auth (API key/JWT/Cognito) and AWS WAF ACL; tighten IAM to least privilege.

### Evidence
- `infra/modules/s3/main.tf` (public access block, OAI policy)
- `infra/modules/cloudfront/main.tf` (HTTPS redirect, OAI)
- `infra/modules/lambda/main.tf` (IAM role, SSM policy)
- `infra/modules/api-gateway/main.tf` (no auth)
- `infra/modules/rds/main.tf` (public SG 0.0.0.0/0)
- `infra/backend.tf` (S3 backend with DynamoDB lock)

### Improvements made (code refs)
- S3 website bucket versioning: `infra/modules/s3/main.tf` lines 9-15
- S3 website bucket encryption: `infra/modules/s3/main.tf` lines 17-26
- S3 artifacts versioning: `infra/modules/s3/main.tf` lines 79-84
- S3 artifacts encryption: `infra/modules/s3/main.tf` lines 86-95
- CloudFront security headers: `infra/modules/cloudfront/main.tf` lines 20-37
- CloudFront TLS minimum: `infra/modules/cloudfront/main.tf` lines 45-48
- API Gateway access logs: `infra/modules/api-gateway/main.tf` lines 101-123
- API GW log group: `infra/modules/api-gateway/main.tf` lines 125-130
- API GW method throttling: `infra/modules/api-gateway/main.tf` lines 132-145
- WAFv2 WebACL (managed rules): `infra/modules/api-gateway/main.tf` lines 147-175
- WAF association: `infra/modules/api-gateway/main.tf` lines 178-181
- Lambda VPC access policy: `infra/modules/lambda/main.tf` lines 21-25
- Lambda security group + VPC: `infra/modules/lambda/main.tf` lines 39-52, 89-92
- RDS SG ingress from Lambda: `infra/modules/rds/main.tf` lines 6-17
- RDS private/encrypted + SG attach: `infra/modules/rds/main.tf` lines 47-58
- IAM narrowed S3 bucket resources: `infra/modules/iam/main.tf` lines 276-279
```9:26:infra/modules/s3/main.tf
resource "aws_s3_bucket_versioning" "website_versioning" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website_encryption" {
  bucket = aws_s3_bucket.website.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
```
```79:95:infra/modules/s3/main.tf
resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts_encryption" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```
```44:47:infra/modules/cloudfront/main.tf
viewer_certificate {
  cloudfront_default_certificate = true
  minimum_protocol_version       = "TLSv1.2_2021"
}
```
```20:37:infra/modules/cloudfront/main.tf
default_cache_behavior {
  allowed_methods  = ["GET", "HEAD"]
  cached_methods   = ["GET", "HEAD"]
  target_origin_id = "s3-origin"

  forwarded_values {
    query_string = false
    cookies {
      forward = "none"
    }
  }

  viewer_protocol_policy     = "redirect-to-https"
  min_ttl                    = 0
  default_ttl                = 3600
  max_ttl                    = 86400
  response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c" # AWSManagedSecurityHeadersPolicy
}
```
```101:123:infra/modules/api-gateway/main.tf
resource "aws_api_gateway_stage" "contact_stage" {
  deployment_id = aws_api_gateway_deployment.contact_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_api.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId",
      ip                      = "$context.identity.sourceIp",
      caller                  = "$context.identity.caller",
      user                    = "$context.identity.user",
      requestTime             = "$context.requestTime",
      httpMethod              = "$context.httpMethod",
      resourcePath            = "$context.resourcePath",
      status                  = "$context.status",
      protocol                = "$context.protocol",
      responseLength          = "$context.responseLength",
      integrationStatus       = "$context.integration.status",
      integrationError        = "$context.integrationErrorMessage"
    })
  }
}
```
```125:145:infra/modules/api-gateway/main.tf
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/apigw/${aws_api_gateway_rest_api.contact_api.id}/${var.stage_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.contact_api.id
  stage_name  = aws_api_gateway_stage.contact_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true
    throttling_burst_limit = 5
    throttling_rate_limit  = 10
  }
}
```
```147:181:infra/modules/api-gateway/main.tf
resource "aws_wafv2_web_acl" "apigw_acl" {
  name        = "apigw-basic-acl"
  description = "Basic protections for API Gateway"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "apigw-acl"
    sampled_requests_enabled   = true
  }
  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "apigw_acl_assoc" {
  resource_arn = aws_api_gateway_stage.contact_stage.arn
  web_acl_arn  = aws_wafv2_web_acl.apigw_acl.arn
}
```
```16:41:infra/modules/lambda/main.tf
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" { policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" }
data "aws_vpc" "default" { default = true }
resource "aws_security_group" "lambda_sg" { egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] } }
```
```89:101:infra/modules/lambda/main.tf
vpc_config {
  subnet_ids         = data.aws_subnets.default_vpc_subnets.ids
  security_group_ids = [aws_security_group.lambda_sg.id]
}
```
```33:41:infra/modules/rds/main.tf
resource "aws_security_group" "rds_ingress" {
  ingress { from_port = 5432 to_port = 5432 protocol = "tcp" security_groups = [var.allowed_sg_id] }
}
```
```48:66:infra/modules/rds/main.tf
resource "aws_db_instance" "contact_db" {
  storage_encrypted   = var.storage_encrypted
  publicly_accessible = var.publicly_accessible
  vpc_security_group_ids = [aws_security_group.rds_ingress.id]
}
```
```276:284:infra/modules/iam/main.tf
        Resource = [
          var.artifacts_bucket_arn,
          var.website_bucket_arn
        ]
```

---

## 3) Reliability
### Current state
- Terraform remote state and locking; CloudFront distribution for static site; API Gateway stage configured.
- RDS backups/maintenance windows configurable; deletion protection flag present.

### Gaps
- No health checks/alarms for API errors or Lambda failures; no DLQ or retries on Lambda.
- RDS not multi-AZ; no dashboards or SLOs; no canary deployments.

### TF improvements
- Add CloudWatch alarms for 4XX/5XX, Lambda errors/duration/timeouts; create dashboards.
- Add Lambda DLQ (SQS) and reserved concurrency; enable API Gateway access logs and execution logging.
- Enable RDS Multi-AZ (if budget) and automated backups; add Route53 health checks (if DNS used).

### Evidence
- `infra/modules/monitoring/main.tf` (only billing alarm)
- `infra/modules/api-gateway/main.tf` (stage definition)
- `infra/modules/lambda/main.tf` (no DLQ)
- `infra/modules/rds/main.tf` (backup/deletion flags)

---

## 4) Performance Efficiency
### Current state
- Static assets via S3 + CloudFront caching with default TTLs; Lambda Node.js runtime.

### Gaps
- No memory/timeout tuning guidance for Lambda; API Gateway caching disabled; unclear asset compression settings.
- RDS instance class static; no DB connection pooling.

### TF improvements
- Tune Lambda memory/timeout; enable API Gateway caching on `contact` resource if appropriate.
- Configure CloudFront compressions (gzip/brotli) and optimized cache behaviors/TTLs; add S3 Cache-Control headers.
- Right-size RDS or consider serverless options; add RDS performance insights (if allowed).

### Evidence
- `infra/modules/cloudfront/main.tf` (cache behavior TTLs)
- `infra/modules/lambda/main.tf` (runtime/timeout vars)
- `infra/modules/api-gateway/main.tf` (no caching)

---

## 5) Cost Optimization
### Current state
- CloudWatch billing alarm configured; artifacts bucket versioning enabled.
- RDS configured for free-tier friendly options; final snapshot skipped to reduce cost.

### Gaps
- S3 lifecycle rules for website/artifacts removed/commented; no asset TTL strategy.
- Always-on RDS; no CloudFront log analysis for cost vs value.

### TF improvements
- Re-enable S3 lifecycle for noncurrent versions and multipart cleanup; set appropriate Cache-Control for static assets.
- Add cost-focused dashboards/alarms (S3 bytes, Lambda duration, API Gateway costs); right-size resources regularly.
- Consider Aurora Serverless v2 if persistence needs grow with variable load.

### Evidence
- `infra/modules/monitoring/main.tf` (billing alarm)
- `infra/modules/s3/main.tf` (artifacts versioning; lifecycle commented out)
- `infra/modules/rds/main.tf` (free-tier settings)

---

## 6) Sustainability
### Current state
- Static hosting with CDN and serverless compute reduces idle waste; web images include WebP formats.

### Gaps
- RDS instance is always-on; caching/TTLs not optimized; no autoscaling or scheduled scale-down.

### TF improvements
- Improve CloudFront/S3 caching and compression; audit and optimize assets; enable brotli.
- Use serverless databases where possible; scale down non-prod; ephemeral preview environments for PRs.

### Evidence
- `web/static/images/*.webp` (optimized images)
- `infra/modules/cloudfront/main.tf` (caching)

---

## Action Items (Optional)
- Priority P0:
  - Remove RDS public ingress and move DB to private subnets with strict SGs.
  - Add API authentication (e.g., Cognito/JWT) and attach AWS WAF to API.
  - Add CloudWatch alarms + SNS for CodeBuild/CodePipeline failures and Lambda errors.
- Priority P1:
  - Place Lambda in VPC and restrict egress; add DLQ and reserved concurrency.
  - Re-enable S3 lifecycle for website/artifacts; set Cache-Control headers via deploy step.
  - Tighten IAM policies for CodeBuild/CodePipeline to least privilege.
- Priority P2:
  - Enable API Gateway access logs/caching; add dashboards for API and Lambda.
  - Evaluate Multi-AZ for RDS and Performance Insights; consider Aurora Serverless v2.
  - Add Terratest-based infra tests in CI and manual approval gates for prod.

## Notes (Optional)
- 
