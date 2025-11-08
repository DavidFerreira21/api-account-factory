# ---------------- DynamoDB ----------------
resource "aws_dynamodb_table" "accounts" {
  name         = "${local.prefix}-ddb-accounts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "AccountEmail"

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
  function_name     = aws_lambda_function.trigger_lambda.arn
  starting_position = "LATEST"
  batch_size        = 10

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

data "archive_file" "lambda_api" {
  type        = "zip"
  source_dir  = "${local.lambda_src_path}/api"
  output_path = "${local.lambda_src_path}/artfacts/api-lambda.zip"
  
}

resource "aws_lambda_function" "accounts_api" {
  function_name    = "${local.prefix}-api-lambda"
  role             = aws_iam_role.lambda_validation_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_api.output_path
  source_code_hash = data.archive_file.lambda_api.output_base64sha256
}


# ---------------- API Gateway Module ----------------

module "accounts_api_gateway" {
  source                  = "./modules/apigw"
  name_prefix             = local.prefix
  stage_name              = "prod"
  lambda_function_name    = aws_lambda_function.accounts_api.function_name
  lambda_function_arn     = aws_lambda_function.accounts_api.arn
  region                  = var.aws_region
  openapi_template_path   = "${path.module}/accounts-api.yaml.tpl"
  log_retention_days      = 30
  endpoint_type           = "REGIONAL"
  vpc_id                  = var.api_gateway_vpc_id
  vpc_subnet_ids          = var.api_gateway_vpc_subnet_ids
  vpc_endpoint_security_group_ids = var.api_gateway_vpc_sg_ids
}
