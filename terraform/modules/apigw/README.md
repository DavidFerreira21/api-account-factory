# API Gateway Module

Provisiona toda a camada de API Gateway (REST) usada pelo Accounts API:

- Importa o template OpenAPI (já com autenticação IAM + integração Lambda);
- Cria logs/role para CloudWatch;
- Opcionalmente cria um endpoint privado (Interface) numa VPC;
- Configura stage, deployment e permissões para invocar a Lambda.

## Exemplo de uso

```hcl
module "accounts_api_gateway" {
  source                = "./modules/apigw"
  name_prefix           = "accfactory"
  stage_name            = "prod"
  lambda_function_name  = module.accounts_api_lambda.function_name
  region                = var.aws_region
  openapi_template_path = "${path.module}/accounts-api.yaml.tpl"

  # API pública
  endpoint_type = "REGIONAL"

  # Para API privada (opcional):
  # vpc_id            = var.api_gateway_vpc_id
  # vpc_subnet_ids    = var.api_gateway_vpc_subnet_ids
  # vpc_allowed_cidrs = var.api_gateway_vpc_allowed_cidrs

  log_retention_days = 30
  tags               = local.default_tags
}
```

## Variáveis principais

| Nome                        | Tipo            | Obrigatório | Descrição                                            |
|-----------------------------|-----------------|-------------|------------------------------------------------------|
| `name_prefix`               | `string`        | Sim         | Prefixo aplicado nos recursos do API Gateway.        |
| `stage_name`                | `string`        | Sim         | Nome do stage (ex.: `prod`).                         |
| `lambda_function_name`      | `string`        | Sim         | Nome da Lambda em que o API Gateway aponta.         |
| `region`                    | `string`        | Sim         | Região AWS usada nas ARNs do template.               |
| `openapi_template_path`     | `string`        | Sim         | Caminho do arquivo OpenAPI usado para importar API. |
| `endpoint_type`             | `string`        | Não         | `REGIONAL`/`EDGE` quando API pública (default `REGIONAL`). |
| `vpc_id`, `vpc_subnet_ids`  | `string` / `list(string)` | Não | Quando definidos, criam endpoint privado Interface. |
| `vpc_allowed_cidrs`         | `list(string)`  | Não         | CIDRs autorizados a acessar o endpoint privado (porta 443). |
| `log_retention_days`        | `number`        | Não         | Retenção dos logs do API (default 30).               |
| `tags`                      | `map(string)`   | Não         | Tags aplicadas aos recursos.                         |

## Outputs

| Nome             | Descrição                          |
|------------------|------------------------------------|
| `rest_api_id`    | ID do API Gateway.                 |
| `invoke_url`     | URL base do stage.                 |
| `stage_arn`      | ARN do stage.                      |
| `vpc_endpoint_id`| ID do endpoint Interface (se criado). |
