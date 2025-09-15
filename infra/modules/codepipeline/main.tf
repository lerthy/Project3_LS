# CodeBuild Projects
resource "aws_codebuild_project" "infra_build" {
  name          = var.infra_build_project_name
  description   = "Build and deploy infrastructure with Terraform"
  service_role  = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

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
    type = "CODEPIPELINE"
    buildspec = var.infra_buildspec_path
  }

  tags = var.tags
}

resource "aws_codebuild_project" "web_build" {
  name          = var.web_build_project_name
  description   = "Build and deploy web application"
  service_role  = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

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
    type = "CODEPIPELINE"
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
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.repository_id
        BranchName       = var.branch_name
        DetectChanges    = "false"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.infra_build.name
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
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.repository_id
        BranchName       = var.branch_name
        DetectChanges    = "false"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web_build.name
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
