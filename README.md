# Accounts API — Automação de Criação de Contas AWS

Este repositório implementa uma API (API Gateway + Lambda) para requisitar e acompanhar a criação de contas AWS usando Control Tower / Service Catalog (Account Factory).

Sumário rápido
- POST /createAccount — cria uma solicitação de conta (validação + grava em DynamoDB)
- GET /getAccount — consulta status/informações de uma conta
- Step Function — orquestra o provisionamento (Validate → ProvisionAccount → Check → Update)

Arquivos importantes
- `API.md` — documentação do fluxo e diagramas (existente)
- `lambda_src/api/lambda_function.py` — handler principal da API (GET/POST)
- `lambda_src/accounts/*.py` — lambdas que compõem o Step Function e processos auxiliares
- `terraform/main-api.tf`, `terraform/main-sfn.tf`, `terraform/providers.tf`, `terraform/data.tf` — infraestrutura Terraform
- Tags padrão: `Solution = https://github.com/DavidFerreira21/api-account-factory`

Variáveis de ambiente relevantes
- `DYNAMO_TABLE` — nome da tabela DynamoDB (obrigatório; defina via Terraform/infra)
- Permissões necessárias (IAM): DynamoDB read/write, Organizations (list roots / OUs), StepFunctions/ServiceCatalog (se provisionamento direto), SQS/SES conforme configuração.

Como rodar localmente (rápido)
1. Preparar credenciais AWS no ambiente (`aws configure`) com permissão adequada.
2. Para testar a Lambda API localmente você pode usar o arquivo `lambda_src/api/lambda_function.py` e simular eventos HTTP (ex.: via script Python ou `awslocal`/SAM). Exemplo de payload POST (JSON):

```json
{
  "AccountEmail": "user@example.com",
  "AccountName": "my-new-account",
  "OrgUnit": "Engineering",
  "SSOUserEmail": "owner@example.com",
  "SSOUserFirstName": "Jean",
  "SSOUserLastName": "Dupont",
  "Tags": [{"Key":"env","Value":"dev"}]
}
```

3. Terraform: para criar infra use os arquivos `*.tf`. Exemplo básico:

```bash
make tf-plan   # terraform init + plan
make tf-apply  # terraform apply
```
