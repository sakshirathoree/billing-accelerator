
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "billing.py"
  output_path = "billing.zip"
}

resource "aws_sns_topic" "billing_topic" {
  name = "billing-lambda-mail"
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.billing_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_billingLambda"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sns_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}


resource "aws_iam_role_policy" "cost_explorer_policy" {
  name = "cost_explorer_policy"
  role = aws_iam_role.iam_for_lambda.id
  #description = "Allows read-only access to Cost Explorer"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ce:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}
resource "aws_lambda_function" "billing_lambda" {
  function_name    = "billing-report-lambda"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "billing.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60

  environment {
    variables = {
      ACCOUNT_ID    = var.account_id
      SNS_TOPIC_ARN = aws_sns_topic.billing_topic.arn
    }
  }
}

resource "aws_ssm_parameter" "vote_sns" {
  name  = "sns_topic_billing"
  type  = "String"
  value = aws_sns_topic.billing_topic.arn
}

resource "aws_lambda_permission" "sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_lambda.function_name
  principal     = "sns.amazonaws.com"

  source_arn = aws_sns_topic.billing_topic.arn
  # Add depends_on to ensure the Lambda function is created first
  depends_on = [aws_lambda_function.billing_lambda]
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        var.account_id,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.billing_topic.arn,
    ]

    sid = "__default_statement_ID"
  }
}

