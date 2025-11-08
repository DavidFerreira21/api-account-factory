locals {
  region     = var.aws_region
  account_id = data.aws_caller_identity.current.account_id

  prefix = "accfactory"


  lambda_src_path = abspath("${path.module}/../lambda_src")


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



