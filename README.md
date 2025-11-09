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
- `DYNAMO_TABLE` — nome da tabela DynamoDB (padrão: `AccountsTable`)
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

Pontos de atenção e boas práticas
- O Lambda usa a variável de ambiente `DYNAMO_TABLE` para o nome da tabela. Padronize seus scripts e Terraform para usar `DYNAMO_TABLE`.
- O código lowercases emails e nomes chave para facilitar buscas e evitar duplicidade por case.
- DynamoDB writes usam ConditionExpression para evitar sobrescrever contas existentes.
- A validação de OU faz chamadas à Organizations e depende de haver ao menos um root.

Sugestões de melhorias futuras (priorizadas)
1. Adicionar um `README` por pasta funcional (`lambda_src/accounts/README.md`) com exemplos de eventos e testes unitários.
2. Adicionar testes unitários minimalistas (pytest) para `lambda_src/api/lambda_function.py` — validar parsing de payload e respostas HTTP.
3. Documentar processo de deploy (como atualizar o `lambda.zip` no Terraform e fatores de idempotência).

Onde procurar
- Fluentemente leia `API.md` para diagramas e fluxo completo.
- `/.github/copilot-instructions.md` contém anotações de arquitetura e convenções (útil para colaboradores).

Se quiser, eu já posso:
- Gerar tests `pytest` básicos para a Lambda API (happy path + 1 erro de validação).
- Adicionar README detalhado dentro de `lambda_src/api` com exemplos de eventos e comandos de teste.

---

Resumo da ação: criei este README geral para fornecer visão rápida do projeto e próximos passos. Se aprovar, adiciono testes e READMEs mais detalhados por pacote.
