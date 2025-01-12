# Define the AWS provider and set the region
provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Owner       = "Terraform-GitHub-Actions"
      Environment = "Prod"
      Service     = "Website-API"
    }
  }
}

