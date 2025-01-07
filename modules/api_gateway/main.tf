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
  uri = var.lambda_invoke_arn ##
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
  function_name = var.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda_cors_api.execution_arn}/*/*"
}
