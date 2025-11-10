# Lambda Module

Pequeno módulo utilizado para empacotar e publicar funções Lambda. Ele aceita tanto `source_dir` quanto `source_file` (mutuamente exclusivos), gera o ZIP via `archive_file` e aplica variáveis/tags/concurrency conforme necessário.

## Exemplo de uso

```hcl
module "accounts_api_lambda" {
  source        = "./modules/lambda"
  function_name = "${local.prefix}-api-lambda"
  role_arn      = aws_iam_role.lambda_validation_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  source_dir    = "${local.lambda_src_path}/api"
  output_path   = "${local.lambda_src_path}/artfacts/api-lambda.zip"
  environment = {
    DYNAMO_TABLE = aws_dynamodb_table.accounts.name
  }
  tags = local.default_tags
}
```

## Variáveis principais

| Nome            | Tipo             | Obrigatório | Descrição                                             |
|-----------------|------------------|-------------|-------------------------------------------------------|
| `function_name` | `string`         | Sim         | Nome da Lambda.                                       |
| `role_arn`      | `string`         | Sim         | ARN da role assumida pela Lambda.                     |
| `handler`       | `string`         | Sim         | Handler no formato `arquivo.função`.                  |
| `runtime`       | `string`         | Sim         | Runtime AWS Lambda (ex.: `python3.11`).               |
| `source_dir`    | `string`         | Condicional | Diretório a ser zipado. Use **ou** `source_file`.     |
| `source_file`   | `string`         | Condicional | Arquivo único a ser zipado. Use **ou** `source_dir`.  |
| `output_path`   | `string`         | Sim         | Caminho do arquivo ZIP gerado.                        |
| `description`   | `string`         | Não         | Descrição da função.                                  |
| `timeout`       | `number`         | Não         | Timeout em segundos (default 60).                     |
| `memory_size`   | `number`         | Não         | Memória em MB (default 128).                          |
| `layers`        | `list(string)`   | Não         | Lista de ARNs de layers.                              |
| `environment`   | `map(string)`    | Não         | Variáveis de ambiente.                                |
| `architectures` | `list(string)`   | Não         | Arquiteturas suportadas (`["x86_64"]` por padrão).    |
| `tags`          | `map(string)`    | Não         | Tags aplicadas à Lambda.                              |
| `kms_key_arn`   | `string`         | Não         | KMS para encriptar variáveis de ambiente.             |

## Outputs

| Nome             | Descrição                      |
|------------------|--------------------------------|
| `arn`            | ARN da Lambda criada.          |
| `function_name`  | Nome da função (útil para refs). |
| `invoke_arn`     | ARN usado em integrações proxy. |
| `qualified_arn`  | ARN qualificado (quando `publish = true`). |
| `source_code_hash` | Hash do pacote (detona updates). |
