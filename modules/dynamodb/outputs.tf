output "dynamodb_name" {
  description = "The name of the DynamoDB table"
  value = aws_dynamodb_table.visits_table.name
}

output "dynamodb_table_dependency" {
  description = "The dependency of the DynamoDB table"
  value = aws_dynamodb_table.visits_table  
}