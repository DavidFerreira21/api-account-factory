locals {
  has_environment = length(var.environment) > 0
}

data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  source_file = var.source_file
  output_path = var.output_path
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.role_arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  description      = var.description
  timeout          = var.timeout
  memory_size      = var.memory_size
  publish          = var.publish
  layers           = var.layers
  architectures    = var.architectures
  tags             = var.tags
  kms_key_arn      = var.kms_key_arn

  dynamic "environment" {
    for_each = local.has_environment ? [1] : []
    content {
      variables = var.environment
    }
  }
}
