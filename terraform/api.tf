# ---------------- DynamoDB ----------------
resource "aws_dynamodb_table" "accounts" {
  name         = "${local.prefix}-ddb-accounts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "AccountEmail"
  tags         = local.default_tags

  attribute {
    name = "AccountEmail"
    type = "S"
  }

  # Habilita o Stream
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

# ---------------- Lambda Event Source Mapping (Trigger SFN) ----------------
resource "aws_lambda_event_source_mapping" "ddb_to_sfn" {
  event_source_arn  = aws_dynamodb_table.accounts.stream_arn
  function_name     = module.trigger_lambda.function_name
  starting_position = "LATEST"
  batch_size        = 1

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
        dynamodb = {
          NewImage = {
            Status = { S = ["Requested"] }
          }
        }
      })
    }
  }
}



# ---------------- Lambda ----------------

module "accounts_api_lambda" {
  source        = "./modules/lambda"
  function_name = "${local.prefix}-api-lambda"
  role_arn      = aws_iam_role.lambda_validation_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  source_dir    = "${local.lambda_src_path}/api"
  output_path   = "${local.lambda_src_path}/artfacts/api-lambda.zip"
  tags          = local.default_tags
  environment = {
    DYNAMO_TABLE       = aws_dynamodb_table.accounts.name
    SFN_ARN            = aws_sfn_state_machine.create_account_sfn.arn
    SFN_MAX_CONCURRENT = "5"
  }
}


# ---------------- API Gateway Module ----------------

module "accounts_api_gateway" {
  source                = "./modules/apigw"
  name_prefix           = local.prefix
  stage_name            = "prod"
  lambda_function_name  = module.accounts_api_lambda.function_name
  region                = var.aws_region
  openapi_template_path = "${path.module}/accounts-api.yaml.tpl"
  log_retention_days    = 30
  endpoint_type         = "REGIONAL"
  vpc_id                = var.api_gateway_vpc_id
  vpc_subnet_ids        = var.api_gateway_vpc_subnet_ids
  vpc_allowed_cidrs     = var.api_gateway_vpc_allowed_cidrs
  tags                  = local.default_tags
}

output "bootstrap_accounts_lambda_name" {
  description = "Nome da Lambda usada para carregar contas existentes do Organizations"
  value       = module.bootstrap_accounts_lambda.function_name
}
