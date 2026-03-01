# Shared global context: AWS identity, naming, and default tags.
locals {
  region     = var.aws_region
  account_id = data.aws_caller_identity.current.account_id

  prefix = var.name_prefix


  lambda_src_path = abspath("${path.module}/../lambda_src")

  default_tags = merge({ Solution = var.solution_url }, var.default_tags)

  bootstrap_lambda_function_name = var.lambda_name_bootstrap_accounts != "" ? var.lambda_name_bootstrap_accounts : "${var.name_prefix}-bootstrap-accounts"
  accounts_api_lambda_name       = var.lambda_name_accounts_api != "" ? var.lambda_name_accounts_api : "${var.name_prefix}-api-lambda"

  lambda_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

}

data "aws_caller_identity" "current" {}
