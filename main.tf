provider "aws" {
  region  = var.aws_region
  profile = "biobio"
}

################# Option 1 #################

# The s3 bucket to use as static web host
resource "aws_s3_bucket" "web_bucket" {
  bucket = var.bucket_name

  force_destroy = true

  tags = {
    Application = "merapar"
  }
}

# Configure the s3 bucket as a web host
resource "aws_s3_bucket_website_configuration" "web_configuration" {
  bucket = aws_s3_bucket.web_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Configure the s3 bucket as public
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.web_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Configure the access policy to the s3 bucket (to allow internet access)
resource "aws_s3_bucket_policy" "allow_public_get" {
  bucket = aws_s3_bucket.web_bucket.id
  policy = data.aws_iam_policy_document.allow_object_access.json
}

# The system manager parameter store, to store the dynamic string
resource "aws_ssm_parameter" "dynamic_string" {
  name  = var.ssm_parameter_name
  type  = "String"
  value = var.initial_string
  overwrite = false

  tags = {
    Application = "merapar"
  }
}

# Package the lambda function code to edit the index.html
data "archive_file" "lambda_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/edit_index.py"
  output_path = "${path.module}/lambda/edit_index.zip"
}

# Lambda function to update the index.html
resource "aws_lambda_function" "update_html" {
  filename         = data.archive_file.lambda_code.output_path
  function_name    = "update_html_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "edit_index.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_code.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.web_bucket.id
      PARAM_NAME  = var.ssm_parameter_name
    }
  }

  tags = {
    Application = "merapar"
  }
}

# Event bridge event to monitor the changes in the dynamic string
resource "aws_cloudwatch_event_rule" "ssm_param_change" {
  name        = "ssm-param-change"
  description = "Trigger when SSM parameter changes"

  event_pattern = <<PATTERN
{
  "source": ["aws.ssm"],
  "detail-type": ["Parameter Store Change"],
  "detail": {
    "name": ["${aws_ssm_parameter.dynamic_string.name}"],
    "operation": ["Update"]
  }
}
PATTERN
}

# Configure the target of the event to invoke a lambda function
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.ssm_param_change.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.update_html.arn
}

# Configure the lambda to be executed from the event bridge
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_html.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ssm_param_change.arn
}

# Run the lambda function at the end to create the first index.html
resource "aws_lambda_invocation" "create_first_index" {
  function_name = aws_lambda_function.update_html.function_name
  input         = "{}"
  depends_on = [
    aws_s3_bucket.web_bucket,
    aws_lambda_function.update_html,
    aws_ssm_parameter.dynamic_string
  ]
}

################# Option 2 #################

# Package the lambda function code to use as a api endpoint
data "archive_file" "lambda_code_host" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_host.py"
  output_path = "${path.module}/lambda/lambda_host.zip"
}

# Lambda function to act as a host
resource "aws_lambda_function" "lambda_host" {
  filename         = data.archive_file.lambda_code_host.output_path
  function_name    = "lambda_host_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_host.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_code_host.output_base64sha256

  environment {
    variables = {
      PARAM_NAME = var.ssm_parameter_name
    }
  }

  tags = {
    Application = "merapar"
  }
}

# Create an Api Gateway to route request to the lambda host
resource "aws_apigatewayv2_api" "http_host" {
  name          = "http_host"
  protocol_type = "HTTP"
}

# Create an integration to call the lambda function from the api
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_host.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_host.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Create the default route of the api
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_host.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Create the default stage
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_host.id
  auto_deploy = true
  name        = "$default"
}

# Configure the lambda function to be executed from the API gateway
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_host.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_host.execution_arn}/*"
}


