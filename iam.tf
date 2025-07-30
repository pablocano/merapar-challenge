# The policy needed for the lambdas
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Creation of a role for the lambdas to use
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# The policy needed to access the S3 bucket and the SSM Parameter
data "aws_iam_policy_document" "aws_lambda_permission" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.web_bucket.arn,
      "${aws_s3_bucket.web_bucket.arn}/*"
    ]
  }
  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.dynamic_string.arn]
  }
}

# Assign of the policy to the lambda role
resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "lambda_role_policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.aws_lambda_permission.json
}

# Policy needed for the S3 bucket to allow internet access
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