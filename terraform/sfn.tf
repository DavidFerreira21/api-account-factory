# Role 1: Execução completa (Service Catalog + Dynamo + etc) para o Lambda de provisionamento
resource "aws_iam_role" "lambda_provisioning_role" {
  name               = "${local.prefix}-provisioning-lambda-role"
  assume_role_policy = local.lambda_assume_role
  tags               = local.default_tags
}

resource "aws_iam_role_policy" "lambda_provisioning_policy" {
  name = "${local.prefix}-provisioning-policy"
  role = aws_iam_role.lambda_provisioning_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.accounts.arn
      },
      {
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.accounts.stream_arn
      },
      {
        Action = [
          "servicecatalog:ProvisionProduct",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DescribeProduct",
          "servicecatalog:SearchProductsAsAdmin",
          "servicecatalog:DescribeProductAsAdmin",
          "servicecatalog:ListPortfoliosForProduct",
          "servicecatalog:AssociatePrincipalWithPortfolio",
          "servicecatalog:DescribeRecord",
          "servicecatalog:ListRecordHistory",
          "servicecatalog:ListPrincipalsForPortfolio",
          "servicecatalog:DescribeProvisionedProduct",
          "servicecatalog:GetProvisionedProductOutputs"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:ListParents",
          "organizations:ListAccounts",
          "organizations:DescribeOrganization",
          "organizations:DescribeOrganizationalUnit",
          "organizations:DescribeAccount",
          "organizations:CreateAccount",
          "organizations:ListCreateAccountStatus",
          "controltower:CreateManagedAccount",
          "controltower:DescribeManagedAccount",
          "controltower:ListManagedAccounts",
          "controltower:DeregisterManagedAccount",
          "sso:*",
          "sso-admin:*",
          "sso-directory:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PassRole",
          "iam:GetRole",
          "iam:PutRolePolicy",
          "iam:CreatePolicy",
          "iam:AttachGroupPolicy"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${local.prefix}-*",
          "arn:aws:iam::${local.account_id}:policy/${local.prefix}-*",
          "arn:aws:iam::${local.account_id}:group/${local.prefix}-*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Role 2: Validação / API (Dynamo + Organizations)
resource "aws_iam_role" "lambda_validation_role" {
  name               = "${local.prefix}-validation-lambda-role"
  assume_role_policy = local.lambda_assume_role
  tags               = local.default_tags
}

resource "aws_iam_role_policy" "lambda_validation_policy" {
  name = "${local.prefix}-validation-lambda-policy"
  role = aws_iam_role.lambda_validation_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.accounts.arn
      },
      {
        Action = [
          "organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "organizations:ListAccounts"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "states:ListExecutions"
        ]
        Effect   = "Allow"
        Resource = aws_sfn_state_machine.create_account_sfn.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Role 3: DynamoDB + Step Functions / Service Catalog leitura
resource "aws_iam_role" "lambda_ddb_sfn_role" {
  name               = "${local.prefix}-ddb-sfn-lambda-role"
  assume_role_policy = local.lambda_assume_role
  tags               = local.default_tags
}

resource "aws_iam_role_policy" "lambda_ddb_sfn_policy" {
  name = "${local.prefix}-ddb-sfn-lambda-policy"
  role = aws_iam_role.lambda_ddb_sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.accounts.arn
      },
      {
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.accounts.stream_arn
      },
      {
        Action = [
          "states:StartExecution"
        ]
        Effect   = "Allow"
        Resource = aws_sfn_state_machine.create_account_sfn.arn
      },
      {
        Action = [
          "servicecatalog:DescribeProvisionedProduct",
          "servicecatalog:GetProvisionedProductOutputs"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ---------------- Lambda Functions ----------------


module "validate_lambda" {
  source        = "./modules/lambda"
  function_name = "Validate_fieldsLambda"
  role_arn      = aws_iam_role.lambda_validation_role.arn
  handler       = "validate_fields.lambda_handler"
  runtime       = "python3.11"
  source_file   = "${local.lambda_src_path}/accounts/validate_fields.py"
  output_path   = "${local.lambda_src_path}/artfacts/validate_fields.zip"
  tags          = local.default_tags
  environment = {
    DYNAMO_TABLE = aws_dynamodb_table.accounts.name
  }
}

module "provision_account_lambda" {
  source        = "./modules/lambda"
  function_name = "ProvisionAccountLambda"
  role_arn      = aws_iam_role.lambda_provisioning_role.arn
  handler       = "provision_account.lambda_handler"
  runtime       = "python3.11"
  timeout       = 600
  source_file   = "${local.lambda_src_path}/accounts/provision_account.py"
  output_path   = "${local.lambda_src_path}/artfacts/provision_account.zip"
  tags          = local.default_tags
  environment = {
    DYNAMO_TABLE  = aws_dynamodb_table.accounts.name
    PRINCIPAL_ARN = aws_iam_role.lambda_provisioning_role.arn
  }
}

module "check_status_lambda" {
  source        = "./modules/lambda"
  function_name = "CheckAccountStatusLambda"
  role_arn      = aws_iam_role.lambda_ddb_sfn_role.arn
  handler       = "check_account_status.lambda_handler"
  runtime       = "python3.11"
  source_file   = "${local.lambda_src_path}/accounts/check_account_status.py"
  output_path   = "${local.lambda_src_path}/artfacts/check_account_status.zip"
  tags          = local.default_tags
}

module "update_status_lambda" {
  source        = "./modules/lambda"
  function_name = "UpdateSucceedStatusLambda"
  role_arn      = aws_iam_role.lambda_ddb_sfn_role.arn
  handler       = "update_succeed_status.lambda_handler"
  runtime       = "python3.11"
  source_file   = "${local.lambda_src_path}/accounts/update_succeed_status.py"
  output_path   = "${local.lambda_src_path}/artfacts/update_succeed_status.zip"
  tags          = local.default_tags
  environment = {
    DYNAMO_TABLE = aws_dynamodb_table.accounts.name
  }
}

module "update_failed_status_lambda" {
  source        = "./modules/lambda"
  function_name = "UpdateFailedStatusLambda"
  role_arn      = aws_iam_role.lambda_ddb_sfn_role.arn
  handler       = "update_failed_status.lambda_handler"
  runtime       = "python3.11"
  source_file   = "${local.lambda_src_path}/accounts/update_failed_status.py"
  output_path   = "${local.lambda_src_path}/artfacts/update_failed_status.zip"
  tags          = local.default_tags
  environment = {
    DYNAMO_TABLE = aws_dynamodb_table.accounts.name
  }
}

module "trigger_lambda" {
  source        = "./modules/lambda"
  function_name = "TriggerSFNLambda"
  role_arn      = aws_iam_role.lambda_ddb_sfn_role.arn
  handler       = "trigger_sfn.lambda_handler"
  runtime       = "python3.11"
  source_file   = "${local.lambda_src_path}/accounts/trigger_sfn.py"
  output_path   = "${local.lambda_src_path}/artfacts/trigger_sfn.zip"
  tags          = local.default_tags
  environment = {
    SFN_ARN = aws_sfn_state_machine.create_account_sfn.arn
  }
}



# ---------------- Step Function ----------------
data "aws_iam_policy_document" "sfn_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn_role" {
  name               = "StepFunctionRole"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role.json
  tags               = local.default_tags
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "StepFunctionPolicy"
  role = aws_iam_role.sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          module.validate_lambda.arn,
          module.provision_account_lambda.arn,
          module.check_status_lambda.arn,
          module.update_status_lambda.arn,
          module.update_failed_status_lambda.arn
        ]
      }
    ]
  })
}

resource "aws_sfn_state_machine" "create_account_sfn" {
  name     = "CreateAccountStateMachine"
  role_arn = aws_iam_role.sfn_role.arn
  tags     = local.default_tags

  definition = templatefile("${path.module}/sfn_definition.json.tpl", {
    validate_lambda             = module.validate_lambda.arn
    provision_lambda            = module.provision_account_lambda.arn
    check_status_lambda         = module.check_status_lambda.arn
    update_status_lambda        = module.update_status_lambda.arn
    update_failed_status_lambda = module.update_failed_status_lambda.arn
  })
}
