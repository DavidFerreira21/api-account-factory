locals {
  is_private_api = var.vpc_id != ""
  endpoint_types = local.is_private_api ? ["PRIVATE"] : [var.endpoint_type]
  account_id     = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

