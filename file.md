# Assignment: AWS CI/CD with S3, CloudFront, Lambda, API Gateway, and RDS (Terraform + Web Pipelines)

In this assignment, you will implement **two CI/CD pipelines** that automate infrastructure provisioning and application deployment on AWS. 
Both pipelines must enforce **linting** and **unit test coverage checks**.

---

## Requirements

### 1. General
- Pipelines must be triggered automatically when changes are pushed to the **`develop` branch**.  
- Repository must contain:
  - A **two-page website** (`index.html`, `contact.html`) with a shared stylesheet.
  - A **Lambda function** (Node.js or Python) that powers the **contact page**.
  - **Terraform code** for infrastructure provisioning.
  - Separate **buildspec files** for infrastructure and application pipelines.

---

### 2. Infrastructure (Terraform Pipeline)
- Use **Terraform** to provision:
  - **S3 bucket** for website hosting.
  - **CloudFront distribution** for global delivery and caching.
  - **API Gateway** to expose the Lambda function.
  - **Lambda function** for contact form processing.
  - **RDS instance** (Postgres ) to store contact form submissions.
- Apply the following **quality checks**:
  - **Linting**: `tflint`, `terraform fmt -check`, `terraform validate`.
  - **Unit testing**: use **Terratest** with minimum **60% coverage**.
- Terraform pipeline must:
  - Run `terraform plan` and `terraform apply`.
  - Fail if linting or tests do not pass.

---

### 3. Application (Web Pipeline)
- Website:
  - Two pages minimum (`index.html` and `contact.html`).
  - Contact form (`name`, `email`, `message`) must POST to API Gateway → Lambda → RDS.
- Frontend Quality:
  - **Linting**: ESLint (JavaScript/TypeScript), Stylelint (CSS).
  - **Unit tests**: Jest/Vitest with **≥70% coverage**.
- Lambda Quality:
  - **Linting**: ESLint (Node) or flake8/ruff (Python).
  - **Unit tests**: Jest/Pytest with **≥70% coverage**.
- Pipeline must:
  - Build the static site (e.g., Vite).
  - Deploy site to **S3**.
  - Deploy Lambda code .
  - Invalidate **CloudFront cache**.
  - Fail if linting or tests do not pass.

---

### 4. Pipeline Setup
- **Terraform Pipeline**: handles infrastructure creation/updates.
- **Web Pipeline**: handles application build and deployment.
- Both pipelines triggered by commits to `develop` branch.
- Secrets (DB creds, S3 bucket name, etc.) must be stored in **AWS Secrets Manager** or **SSM Parameter Store**, not hardcoded.

---

## Demonstration
During the demo, you must show:
1. Pipelines trigger automatically on push to `develop` branch.
2. A linting or unit test error causes the pipeline to fail.
3. Fixing the issues allows the pipeline to succeed.
4. Successful infrastructure provisioning with Terraform pipeline.
5. Successful deployment of the two-page site via Web pipeline.
6. CloudFront URL serves the website.
7. Submitting the contact form stores data in RDS (verify with DB query).
8. CloudFront invalidation ensures updated site content is visible immediately.

---

## Deliverables
- Git repository containing:
  - `/infra` Terraform code with tests and lint configs.
  - `/web` website + Lambda code with tests and lint configs.
  - Buildspec files for both pipelines.
  - `README.md` with setup instructions, architecture diagram, and demo steps. 
- Screenshots or links showing:
  - Pipeline failures (lint/test errors).
  - Pipeline successes (deploys).
  - CloudFront URL of deployed website.
  - Contact form data successfully stored in RDS.
  