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

# Create a zip archive of the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_func"
  output_path = "${path.module}/lambda.zip"
}

# Create the Lambda function
resource "aws_lambda_function" "visit_counter_lambda_function" {
  function_name = var.lambda_function_name
  filename = "${data.archive_file.lambda_zip.output_path}"
  role          = aws_iam_role.lambda_role.arn
  runtime = "python3.13"
  handler = "${var.lambda_function_name}.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
  depends_on = [ var.table_dependency, data.archive_file.lambda_zip ]
}

# Attach the AmazonDynamoDBFullAccess policy to the Lambda IAM role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
