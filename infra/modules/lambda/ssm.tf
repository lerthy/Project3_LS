resource "aws_ssm_parameter" "lambda_function_name" {
  name  = "/lambda/lambda_function_name"
  type  = "String"
  value = aws_lambda_function.contact.function_name

  tags = var.tags
}

resource "aws_ssm_parameter" "lambda_function_arn" {
  name  = "/lambda/lambda_function_arn"
  type  = "String"
  value = aws_lambda_function.contact.arn

  tags = var.tags
}

resource "aws_ssm_parameter" "lambda_invoke_arn" {
  name  = "/lambda/lambda_invoke_arn"
  type  = "String"
  value = aws_lambda_function.contact.invoke_arn

  tags = var.tags
}

resource "aws_ssm_parameter" "lambda_role_arn" {
  name  = "/lambda/lambda_role_arn"
  type  = "String"
  value = aws_iam_role.lambda_exec.arn

  tags = var.tags
}
