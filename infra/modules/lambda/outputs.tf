output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.contact.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.contact.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.contact.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

# KMS Key Outputs
output "lambda_kms_key_arn" {
  description = "ARN of the KMS key used for Lambda environment variables encryption"
  value       = aws_kms_key.lambda_env_encryption.arn
}

output "lambda_kms_key_alias" {
  description = "Alias of the KMS key used for Lambda environment variables encryption"
  value       = aws_kms_alias.lambda_env_encryption.name
}
