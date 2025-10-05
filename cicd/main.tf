# CodeStar Connection for GitHub
resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection-project3"
  provider_type = "GitHub"

  tags = var.tags
}

# Data source for GitHub webhook secret
data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "project3/github-webhook"
}

# SNS Topic for Manual Approvals
resource "aws_sns_topic" "manual_approval" {
  name = "cicd-manual-approval-${var.environment}"

  tags = merge(var.tags, {
    Name = "manual-approval-${var.environment}"
    Type = "operational-excellence"
  })
}

resource "aws_sns_topic_subscription" "manual_approval_email" {
  count     = var.approval_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.manual_approval.arn
  protocol  = "email"
  endpoint  = var.approval_email
}

# CodeBuild Projects
resource "aws_codebuild_project" "infra_build" {
  name         = var.infra_build_project_name
  description  = "Build and deploy infrastructure with Terraform"
  service_role = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "TF_VAR_aws_region"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.infra_buildspec_path
  }

  tags = var.tags
}

resource "aws_codebuild_project" "web_build" {
  name         = var.web_build_project_name
  description  = "Build and deploy web application"
  service_role = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.web_buildspec_path
  }

  tags = var.tags
}

# Infrastructure Pipeline (Terraform)
resource "aws_codepipeline" "infra_pipeline" {
  name     = var.infra_pipeline_name
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.artifacts_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.repository_id
        BranchName           = var.branch_name
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.infra_build.name
      }
    }
  }

  # Manual Approval Stage for Production Infrastructure Changes
  dynamic "stage" {
    for_each = var.environment == "production" ? [1] : []

    content {
      name = "ManualApproval"

      action {
        name     = "ManualApprovalForProduction"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          NotificationArn = aws_sns_topic.manual_approval.arn
          CustomData      = "Please review the infrastructure changes for ${var.environment} environment before proceeding with deployment."
        }
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.infra_build.name
        EnvironmentVariables = jsonencode([
          {
            name  = "DEPLOYMENT_STAGE"
            value = "DEPLOY"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
}

# Web Application Pipeline
resource "aws_codepipeline" "web_pipeline" {
  name     = var.web_pipeline_name
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.artifacts_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.repository_id
        BranchName           = var.branch_name
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web_build.name
      }
    }
  }

  # Manual Approval Stage for Production Web Application Changes
  dynamic "stage" {
    for_each = var.environment == "production" ? [1] : []

    content {
      name = "ManualApproval"

      action {
        name     = "ManualApprovalForWebProduction"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          NotificationArn = aws_sns_topic.manual_approval.arn
          CustomData      = "Please review the web application changes for ${var.environment} environment before proceeding with deployment."
        }
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web_build.name
        EnvironmentVariables = jsonencode([
          {
            name  = "DEPLOYMENT_STAGE"
            value = "DEPLOY"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
}


# Webhook for Infrastructure Pipeline
resource "aws_codepipeline_webhook" "infra_webhook" {
  name            = "${var.infra_pipeline_name}-webhook"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.infra_pipeline.name

  authentication_configuration {
    secret_token = var.github_webhook_secret
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/${var.branch_name}"
  }

  filter {
    json_path    = "$.commits[*].modified[*]"
    match_equals = "infra/**"
  }
}

# Webhook for Web Pipeline
resource "aws_codepipeline_webhook" "web_webhook" {
  name            = "${var.web_pipeline_name}-webhook"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.web_pipeline.name

  authentication_configuration {
    secret_token = var.github_webhook_secret
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/${var.branch_name}"
  }

  filter {
    json_path    = "$.commits[*].modified[*]"
    match_equals = "web/**"
  }
}


