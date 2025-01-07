output "base_api_url" {
    value = aws_api_gateway_stage.lambda_stage.invoke_url
    description = "The base URL of the API Gateway" 
}

output "route_key" {
    value = aws_api_gateway_resource.update_visits.path_part
    description = "The route key of the API Gateway route"
}