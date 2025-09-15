## Project: AWS CI/CD with S3, CloudFront, Lambda, API Gateway, and RDS

This repository implements two CI/CD pipelines (Infrastructure and Web) that provision AWS infrastructure with Terraform and deploy a two-page static website with a contact form backed by API Gateway → Lambda → RDS (PostgreSQL).

Both pipelines enforce linting and unit test coverage thresholds./////

### Repository Structure

```
infra/                # Terraform for S3, CloudFront, API Gateway, Lambda, RDS
  *.tf
  tests/              # Terratest integration test (go)
web/
  static/             # index.html, contact.html, css, images, js
  lambda/             # Lambda function (Node.js + Jest tests)
  test/               # Frontend tests (Vitest)
  eslint.config.js    # ESLint (flat config) for frontend
  .stylelintrc.json   # Stylelint config for CSS linting
buildspec-infra.yml   # CodeBuild spec for Terraform pipeline
web/buildspec-web.yml # CodeBuild spec for Web pipeline
```

### Prerequisites

- AWS account with permissions to use: S3, CloudFront, API Gateway, Lambda, RDS, SSM Parameter Store, IAM
- CodeBuild/CodePipeline (or GitHub Actions) environment variables configured as noted below
- Node.js 18+, Go 1.21+, Terraform 1.6+

### Secrets and Parameters (Security)

Do not hardcode secrets. This project reads DB credentials from AWS Systems Manager Parameter Store by default.

Create the following SSM parameters (use SecureString for password):

- `/project3/db/username` (String) — e.g., `appuser`
- `/project3/db/password` (SecureString) — strong password
- `/project3/db/name` (String) — e.g., `contacts`

Terraform variables allow overriding via `-var` flags, but if left empty the module reads from SSM:

- `db_username`, `db_password`, `db_name` (optional overrides)
- `db_username_ssm_name`, `db_password_ssm_name`, `db_name_ssm_name` (defaults set)

### CI/CD Pipelines

Trigger: push to `develop` branch (configure your CI to watch this branch).

1) Infrastructure Pipeline (`buildspec-infra.yml`):
- Installs Terraform and tflint
- Runs: `terraform fmt -check`, `terraform validate`, `tflint`
- Runs Terratest with coverage (min 60%)
- Packages Lambda from `web/lambda` into `infra/lambda.zip`
- Runs `terraform plan` and (for non-PR events) `terraform apply`

2) Web Pipeline (`web/buildspec-web.yml`):
- Installs frontend and Lambda deps
- Lints: ESLint (frontend + Lambda), Stylelint (CSS)
- Tests: Vitest (frontend) and Jest (Lambda) with ≥70% thresholds
- Replaces API endpoint in `web/static/js/config.js` with `API_GATEWAY_URL`
- Syncs `web/static/` to S3, updates Lambda code, invalidates CloudFront

### Required CI Environment Variables

Set these for the Web pipeline:

- `S3_BUCKET_NAME` — from Terraform output `bucket_name`
- `CLOUDFRONT_DISTRIBUTION_ID` — the distribution ID created by Terraform
- `API_GATEWAY_URL` — from Terraform output `api_gateway_url`

For Terraform pipeline, ensure your build role has permissions for S3, CF, APIGW, Lambda, RDS, SSM, IAM.

### Local Development

Frontend:

```
cd web
npm install
npm run lint
npm run test
```

Lambda:

```
cd web/lambda
npm install
npm run lint
npm test
```

Terraform (dry run):

```
cd infra
terraform init -backend=false
terraform validate
terraform plan -var "db_password=TestPassw0rd!"
```

### Testing and Coverage Thresholds

- Frontend (Vitest) thresholds: 70% global (branches, functions, lines, statements)
- Lambda (Jest) thresholds: 70% global
- Terraform (Terratest) coverage: ≥60%

### Demo Steps Checklist

1. Push a commit to `develop` and show both pipelines trigger
2. Introduce a lint/test failure and show pipeline fails, then fix and rerun
3. Show successful Terraform apply: outputs include bucket, CloudFront, API URL, RDS endpoint
4. Deploy website, verify CloudFront URL serves pages
5. Submit contact form; verify record exists in RDS (e.g., query `contacts` table)
6. Redeploy site and show CloudFront invalidation reflects changes immediately

### Notes and Trade-offs

- RDS is configured for simplicity; for real deployments, place RDS in private subnets and run Lambda in a VPC with appropriate security groups. Public accessibility is disabled by default here; adjust networking if needed.
- Secrets are read from SSM at runtime by Terraform to set Lambda env vars and DB auth.

### Outputs

After `terraform apply`, capture:

- `bucket_name`
- `cloudfront_url`
- `api_gateway_url`
- `rds_endpoint`

Use these to configure the Web pipeline environment variables.
