provider "aws" {
  region  = var.aws_region
  profile = "biobio"
}

resource "aws_s3_bucket" "web_bucket" {
  bucket = var.bucket_name

  tags = {
    Application = "merapar"
  }
}

resource "aws_s3_bucket_website_configuration" "web_configuration" {
  bucket = aws_s3_bucket.web_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.web_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_get" {
  bucket = aws_s3_bucket.web_bucket.id
  policy = data.aws_iam_policy_document.allow_object_access.json
}

data "aws_iam_policy_document" "allow_object_access" {
  statement {
    actions = ["s3:GetObject"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    resources = [
      aws_s3_bucket.web_bucket.arn,
      "${aws_s3_bucket.web_bucket.arn}/*"
    ]
  }
}

resource "aws_ssm_parameter" "dynamic_string" {
  name  = var.ssm_parameter_name
  type  = "String"
  value = var.initial_string

  tags = {
    Application = "merapar"
  }
}

# Package the Lambda function code
data "archive_file" "lambda_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/edit_index.py"
  output_path = "${path.module}/lambda/function.zip"
}

# Lambda function
resource "aws_lambda_function" "update_html" {
  filename      = data.archive_file.lambda_code.output_path
  function_name = "update_html_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "edit_index.lambda_handler"
  runtime       = "python3.12"

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

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.ssm_param_change.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.update_html.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_html.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ssm_param_change.arn
}



