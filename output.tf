output "lambda" {
  value = aws_lambda_function.billing_lambda.qualified_arn
}

output "sns_topic_name" {
  value = aws_sns_topic.billing_topic.arn
}
