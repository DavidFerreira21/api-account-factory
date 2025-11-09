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
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
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
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
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
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Role para Service Catalog (Launch Role)
resource "aws_iam_role" "servicecatalog_launch_role" {
  name = "accounts_servicecatalog_launch_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "servicecatalog.amazonaws.com"
        }
      }
    ]
  })
  tags = local.default_tags
}

resource "aws_iam_role_policy" "servicecatalog_launch_policy" {
  name = "accounts_servicecatalog_launch_policy"
  role = aws_iam_role.servicecatalog_launch_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
          "organizations:ListCreateAccountStatus"
        ]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "controltower:CreateManagedAccount",
          "controltower:DescribeManagedAccount",
          "controltower:ListManagedAccounts",
          "controltower:DeregisterManagedAccount"
        ]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sso:*",
          "sso-admin:*",
          "sso-directory:*"
        ]
        Effect = "Allow"
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
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}




# ---------------- Lambda Functions ----------------


# Função Validate
data "archive_file" "validate_zip" {
  type        = "zip"
  source_file = "${local.lambda_src_path}/accounts/validate_fields.py"
  output_path = "${local.lambda_src_path}/artfacts/validate_fields.zip"
  
}

resource "aws_lambda_function" "validate" {
  function_name    = "Validate_fieldsLambda"
  role             = aws_iam_role.lambda_validation_role.arn
  handler          = "validate_fields.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.validate_zip.output_path
  source_code_hash = data.archive_file.validate_zip.output_base64sha256
  tags             = local.default_tags
}

# Função ProvisionAccount
data "archive_file" "provision_zip" {
  type        = "zip"
  source_file  = "${local.lambda_src_path}/accounts/provision_account.py"
  output_path = "${local.lambda_src_path}/artfacts/provision_account.zip"
}

resource "aws_lambda_function" "provision_account" {
  function_name    = "ProvisionAccountLambda"
  role             = aws_iam_role.lambda_provisioning_role.arn
  handler          = "provision_account.lambda_handler"
  runtime          = "python3.11"
  timeout          = 600 
  filename         = data.archive_file.provision_zip.output_path
  source_code_hash = data.archive_file.provision_zip.output_base64sha256
  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.accounts.name
      PRINCIPAL_ARN = aws_iam_role.servicecatalog_launch_role.arn
    }
  }
  tags = local.default_tags
}

# Função CheckAccountStatus
data "archive_file" "checkstatus_zip" {
  type        = "zip"
  source_file  = "${local.lambda_src_path}/accounts/check_account_status.py"
  output_path = "${local.lambda_src_path}/artfacts/check_account_status.zip"
}

resource "aws_lambda_function" "check_status" {
  function_name    = "CheckAccountStatusLambda"
  role             = aws_iam_role.lambda_ddb_sfn_role.arn
  handler          = "check_account_status.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.checkstatus_zip.output_path
  source_code_hash = data.archive_file.checkstatus_zip.output_base64sha256
  tags             = local.default_tags
}

# Função UpdateStatus
data "archive_file" "update_zip" {
  type        = "zip"
  source_file  = "${local.lambda_src_path}/accounts/update_succeed_status.py"
  output_path = "${local.lambda_src_path}/artfacts/update_succeed_status.zip"
}

resource "aws_lambda_function" "update_status" {
  function_name    = "UpdateSucceedStatusLambda"
  role             = aws_iam_role.lambda_ddb_sfn_role.arn
  handler          = "update_succeed_status.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.update_zip.output_path
  source_code_hash = data.archive_file.update_zip.output_base64sha256
  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.accounts.name
    }
  }
  tags = local.default_tags
}

data "archive_file" "update_failed_zip" {
  type        = "zip"
  source_file  = "${local.lambda_src_path}/accounts/update_failed_status.py"
  output_path = "${local.lambda_src_path}/artfacts/update_failed_status.zip"
}

resource "aws_lambda_function" "update_failed_status" {
  function_name    = "UpdateFailedStatusLambda"
  role             = aws_iam_role.lambda_ddb_sfn_role.arn
  handler          = "update_failed_status.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.update_failed_zip.output_path
  source_code_hash = data.archive_file.update_failed_zip.output_base64sha256
  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.accounts.name
    }
  }
  tags = local.default_tags
}


# Lambda da trigger
data "archive_file" "trigger_zip" {
  type        = "zip"
  source_file = "${local.lambda_src_path}/accounts/trigger_sfn.py"
  output_path = "${local.lambda_src_path}/artfacts/trigger_sfn.zip"
}

resource "aws_lambda_function" "trigger_lambda" {
  function_name    = "TriggerSFNLambda"
  role             = aws_iam_role.lambda_ddb_sfn_role.arn
  handler          = "trigger_sfn.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.trigger_zip.output_path
  source_code_hash = data.archive_file.trigger_zip.output_base64sha256
  environment {
    variables = {
      SFN_ARN = aws_sfn_state_machine.create_account_sfn.arn
    }
  }
  tags = local.default_tags
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
          aws_lambda_function.validate.arn,
          aws_lambda_function.provision_account.arn,
          aws_lambda_function.check_status.arn,
          aws_lambda_function.update_status.arn,
          aws_lambda_function.update_failed_status.arn
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
    validate_lambda       = aws_lambda_function.validate.arn
    provision_lambda      = aws_lambda_function.provision_account.arn
    check_status_lambda   = aws_lambda_function.check_status.arn
    update_status_lambda  = aws_lambda_function.update_status.arn
    update_failed_status_lambda  = aws_lambda_function.update_failed_status.arn
  })
}
