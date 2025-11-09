

resource "aws_security_group" "apigw_endpoint" {
  count = local.is_private_api ? 1 : 0

  name   = "${var.name_prefix}-apigw-endpoint-sg"
  vpc_id = var.vpc_id
  tags   = var.tags

  ingress {
    description = "Allow HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.vpc_allowed_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "execute_api" {
  count               = local.is_private_api ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.vpc_subnet_ids
  security_group_ids  = aws_security_group.apigw_endpoint[*].id
  private_dns_enabled = true
  tags                = var.tags
}

resource "aws_iam_role" "api_gw_logs_role" {
  name = "${var.name_prefix}-api-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gw_logs_policy" {
  name = "${var.name_prefix}-api-logs-policy"
  role = aws_iam_role.api_gw_logs_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gw_logs_managed_policy" {
  role       = aws_iam_role.api_gw_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${var.name_prefix}-api-gateway"
  body = templatefile(var.openapi_template_path, {
    region     = var.region
    account_id = local.account_id
    name       = var.lambda_function_name
  })

  endpoint_configuration {
    types            = local.endpoint_types
    vpc_endpoint_ids = local.is_private_api ? [aws_vpc_endpoint.execute_api[0].id] : null
  }
  tags = var.tags
}

resource "aws_api_gateway_rest_api_policy" "private_policy" {
  count       = local.is_private_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "execute-api:Invoke",
        Resource  = "arn:aws:execute-api:${var.region}:${local.account_id}:${aws_api_gateway_rest_api.this.id}/*",
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.execute_api[0].id
          }
        }
      }
    ]
  })
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${local.account_id}:${aws_api_gateway_rest_api.this.id}/*/*"
}

resource "aws_api_gateway_deployment" "this" {
  depends_on  = [aws_lambda_permission.api_gateway]
  rest_api_id = aws_api_gateway_rest_api.this.id
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/${var.name_prefix}-api-gateway-logs"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_api_gateway_account" "account_settings" {
  cloudwatch_role_arn = aws_iam_role.api_gw_logs_role.arn
  depends_on = [
    aws_iam_role.api_gw_logs_role,
    aws_iam_role_policy.api_gw_logs_policy
  ]
}

resource "aws_api_gateway_stage" "stage" {
  depends_on    = [aws_api_gateway_account.account_settings]
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.this.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId",
      ip             = "$context.identity.sourceIp",
      caller         = "$context.identity.caller",
      user           = "$context.identity.user",
      requestTime    = "$context.requestTime",
      httpMethod     = "$context.httpMethod",
      resourcePath   = "$context.resourcePath",
      status         = "$context.status",
      protocol       = "$context.protocol",
      responseLength = "$context.responseLength"
    })
  }
}
