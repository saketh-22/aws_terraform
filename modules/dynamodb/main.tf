
# Create a DynamoDB table to store visit counts
resource "aws_dynamodb_table" "visits_table" {
  name           = var.dynamodb_table_name
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