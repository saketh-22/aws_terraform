# Configure the Terraform AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Define the AWS provider and set the region
provider "aws" {
  region = "eu-north-1"
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
    "Effect": "Allow",
    "Principal": {
        "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
    }
]
}
EOF
}

# Attach the AWSLambdaBasicExecutionRole policy to the Lambda IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach the AmazonDynamoDBFullAccess policy to the Lambda IAM role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Create a zip archive of the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_func"
  output_path = "${path.module}/lambda.zip"
}

# Create the Lambda function
resource "aws_lambda_function" "visit_counter_lambda_function" {
  function_name = "visit_counter_lambda_function"
  filename = "${data.archive_file.lambda_zip.output_path}"
  role          = aws_iam_role.lambda_role.arn
  runtime = "python3.13"
  handler = "visit_counter_lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visits_table.name
    }
  }
  depends_on = [ aws_dynamodb_table.visits_table, data.archive_file.lambda_zip ]
}

# Create a DynamoDB table to store visit counts
resource "aws_dynamodb_table" "visits_table" {
  name           = "visits_table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "page_url"
  attribute {
    name = "page_url"
    type = "S"
  }
  attribute {
    name = "visit_count"
    type = "N"
  }
  global_secondary_index {
    name            = "visit_count_index"
    hash_key        = "visit_count"
    projection_type = "ALL"
  }
}

# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "lambda_cors_api" {
  name        = "lambda_cors_api"
  description = "API Gateway for the Lambda function with CORS enabled"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create a resource for the API Gateway
resource "aws_api_gateway_resource" "update_visits" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  parent_id   = aws_api_gateway_rest_api.lambda_cors_api.root_resource_id
  path_part   = "visits"
}

# Create a POST method for the API Gateway
resource "aws_api_gateway_method" "post_method" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = "POST"
  authorization = "NONE"
}

# Create an integration for the POST method
resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri = aws_lambda_function.visit_counter_lambda_function.invoke_arn
  request_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
  "httpMethod": "$context.httpMethod",
  "path": "$context.resourcePath",
  "queryStringParameters": {
    #foreach($param in $input.params().querystring.keySet())
      "$param": "$util.escapeJavaScript($input.params().querystring.get($param))"
      #if($foreach.hasNext),#end
    #end
  },
  "update": "$input.params().querystring.update",
  "headers": {
    #foreach($header in $input.params().header.keySet())
      "$header": "$util.escapeJavaScript($input.params().header.get($header))"
      #if($foreach.hasNext),#end
    #end
  },
  "body": "$util.escapeJavaScript($input.json('$'))"
}
EOF
  }
  passthrough_behavior = "WHEN_NO_TEMPLATES"
}

# Create a method response for the POST method
resource "aws_api_gateway_method_response" "post_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Create an integration response for the POST method
resource "aws_api_gateway_integration_response" "post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = aws_api_gateway_method_response.post_response.status_code
  response_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
  "statusCode": "$inputRoot.statusCode",
  "body": $inputRoot.body
}
EOF
  }
  depends_on = [aws_api_gateway_integration.post_integration]
}

# Create a OPTIONS method for the API Gateway with CORS enabled
resource "aws_api_gateway_method" "options_method" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = "OPTIONS"
  authorization = "NONE"  
}

# Create a method response for the OPTIONS method
resource "aws_api_gateway_method_response" "options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Create an integration for the OPTIONS method
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = aws_api_gateway_method.options_method.http_method
  integration_http_method = "OPTIONS"
  type = "MOCK"
  request_templates = {
    "application/json" = <<EOF
{
  "statusCode": 200
}
EOF
  }
  depends_on = [ aws_api_gateway_method.options_method ]
}

# Create an integration response for the OPTIONS method
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  resource_id = aws_api_gateway_resource.update_visits.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_method_response.status_code
  response_templates = {
    "application/json" = <<EOF
{
  "statusCode": 200
}
EOF
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [ aws_api_gateway_integration.options_integration ]
}





# Create a stage for the API Gateway
resource "aws_api_gateway_stage" "lambda_stage" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  stage_name  = "prod"
  deployment_id = aws_api_gateway_deployment.lambda_cors_api_deployment.id
}

# Create a deployment for the API Gateway
resource "aws_api_gateway_deployment" "lambda_cors_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lambda_cors_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.post_integration,
      aws_api_gateway_integration.options_integration,
      aws_api_gateway_resource.update_visits.id
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}
# The triggers argument should be preferred over depends_on, 
# since depends_on can only capture dependency ordering and
# will not cause the resource to recreate (redeploy the REST API) with upstream configuration changes.


# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visit_counter_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda_cors_api.execution_arn}/*/*"
}
