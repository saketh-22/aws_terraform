output "function_name" {
  description = "The name of the Lambda function"
  value = aws_lambda_function.visit_counter_lambda_function.function_name
}

output "dynamodb_name" {
  description = "The name of the DynamoDB table"
  value = aws_dynamodb_table.visits_table.name
  
}

output "filename" {
    value = data.archive_file.lambda_zip.output_path
    description = "value of the filename" 
}

output "base_api_url" {
    value = aws_api_gateway_stage.lambda_stage.invoke_url
    description = "The base URL of the API Gateway" 
}

output "route_key" {
    value = aws_api_gateway_resource.update_visits.path_part
    description = "The route key of the API Gateway route"
}