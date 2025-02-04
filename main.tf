# Configure the Terraform AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-bucket-2000"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-state-lock"
    region = "eu-north-1"
  }
}


module "dynamodb" {
  source = "./modules/dynamodb"
  
}

module "lambda" {
  source = "./modules/lambda"
  table_name = module.dynamodb.dynamodb_name
  table_dependency = module.dynamodb.dynamodb_table_dependency
}

module "api_gateway" {
  source = "./modules/api_gateway"
  lambda_name = module.lambda.lambda_name
  lambda_invoke_arn = module.lambda.lambda_invoke_arn
}
