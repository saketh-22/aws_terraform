output "lambda_name" {
  description = "The name of the Lambda function"
  value = aws_lambda_function.visit_counter_lambda_function.function_name
}

output "lambda_arn" {
  description = "The ARN of the Lambda function"
  value = aws_lambda_function.visit_counter_lambda_function.arn
}

output "lambda_invoke_arn" {
  description = "The invoke ARN of the Lambda function"
  value = aws_lambda_function.visit_counter_lambda_function.invoke_arn
}

output "iam_role_name" {
  description = "The name of the IAM role"
  value = aws_iam_role.lambda_role.name
  
}

