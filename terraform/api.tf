# ---------------- DynamoDB ----------------
# Central table storing request and account state.
resource "aws_dynamodb_table" "accounts" {
  name         = "${local.prefix}-ddb-accounts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "AccountEmail"
  tags         = local.default_tags

  attribute {
    name = "AccountEmail"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  # Enable DynamoDB Stream.
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

# ---------------- Lambda Event Source Mapping (Trigger SFN) ----------------
# Route Requested inserts to the Lambda that starts the Step Function.
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
# API HTTP Lambda (synchronous ingress).

module "accounts_api_lambda" {
  source                         = "./modules/lambda"
  function_name                  = local.accounts_api_lambda_name
  role_arn                       = aws_iam_role.lambda_validation_role.arn
  handler                        = "lambda_function.lambda_handler"
  runtime                        = var.lambda_runtime_default
  source_dir                     = "${local.lambda_src_path}/api"
  output_path                    = "${local.lambda_src_path}/artfacts/api-lambda.zip"
  tags                           = local.default_tags
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  environment = {
    DYNAMO_TABLE       = aws_dynamodb_table.accounts.name
    SFN_ARN            = aws_sfn_state_machine.create_account_sfn.arn
    SFN_MAX_CONCURRENT = tostring(var.sfn_max_concurrent)
  }
}


# ---------------- API Gateway Module ----------------
# HTTP exposure layer (public or private based on variables).

module "accounts_api_gateway" {
  source                = "./modules/apigw"
  name_prefix           = local.prefix
  stage_name            = var.api_gateway_stage_name
  lambda_function_name  = module.accounts_api_lambda.function_name
  region                = var.aws_region
  openapi_template_path = "${path.module}/accounts-api.yaml.tpl"
  log_retention_days    = var.api_gateway_log_retention_days
  endpoint_type         = var.api_gateway_endpoint_type
  vpc_id                = var.api_gateway_vpc_id
  vpc_subnet_ids        = var.api_gateway_vpc_subnet_ids
  vpc_allowed_cidrs     = var.api_gateway_vpc_allowed_cidrs
  tags                  = local.default_tags
}

output "bootstrap_accounts_lambda_name" {
  description = "Lambda name used to bootstrap existing Organizations accounts"
  value       = module.bootstrap_accounts_lambda.function_name
}

output "api_rest_api_id" {
  description = "API Gateway ID"
  value       = module.accounts_api_gateway.rest_api_id
}

output "api_invoke_url" {
  description = "API Gateway base invoke URL"
  value       = module.accounts_api_gateway.invoke_url
}
