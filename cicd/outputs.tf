output "infra_pipeline_name" {
  description = "Name of the infrastructure CodePipeline"
  value       = aws_codepipeline.infra_pipeline.name
}

output "web_pipeline_name" {
  description = "Name of the web application CodePipeline"
  value       = aws_codepipeline.web_pipeline.name
}

output "infra_build_project_name" {
  description = "Name of the infrastructure CodeBuild project"
  value       = aws_codebuild_project.infra_build.name
}

output "web_build_project_name" {
  description = "Name of the web application CodeBuild project"
  value       = aws_codebuild_project.web_build.name
}

output "infra_webhook_url" {
  description = "Webhook URL for infrastructure pipeline"
  value       = aws_codepipeline_webhook.infra_webhook.url
}

output "web_webhook_url" {
  description = "Webhook URL for web pipeline"
  value       = aws_codepipeline_webhook.web_webhook.url
}

output "codestar_connection_arn" {
  description = "ARN of the CodeStar Connection to GitHub"
  value       = aws_codestarconnections_connection.github.arn
}

output "codestar_connection_status" {
  description = "Status of the CodeStar Connection to GitHub"
  value       = aws_codestarconnections_connection.github.connection_status
}
