variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "visit_counter_lambda_function"
}

variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "table_dependency" {
  description = "The dependency of the DynamoDB table"
  type        = any  
}