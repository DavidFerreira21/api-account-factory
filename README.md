# Accounts API — Automação de Criação de Contas AWS

API Gateway + Lambda que registra solicitações de contas AWS, valida dados e aciona uma Step Function para orquestrar o provisionamento via Control Tower / Service Catalog.

## Referência principal
- `documentation.md` concentra arquitetura completa, payloads e fluxos (sempre consultar primeiro).

## Visão rápida da solução
- **POST `/createAccount`** → valida payload, impede duplicidades e grava no DynamoDB (`Status=Requested`).
- **GET `/getAccount`** → consulta pelo `accountEmail` ou `accountId`.
- **Step Function** → `Validate → ProvisionAccount → CheckAccountStatus (loop 5min, máx. 20x) → UpdateSuccess/Failed`.
- **Observabilidade** → CloudWatch Logs (API Gateway + Lambdas) e `RequestID` propagado para correlacionar eventos.

## Estrutura do repositório
- `lambda_src/api/lambda_function.py` — handler HTTP (GET/POST).
- `lambda_src/accounts/*.py` — Lambdas do fluxo (validação, provisionamento, atualização de status, trigger da SFN).
- `terraform/` — infraestrutura (DynamoDB, Lambdas, IAM, API Gateway, Step Function).
- `tests/` — ponto inicial para cenários unitários/integração.

## Pré-requisitos
- Credenciais AWS com permissão para DynamoDB, Organizations, Service Catalog, Step Functions e CloudWatch.
- Python 3.11+ e Make (para rodar `make test`, `make tf-plan`, etc.).
- Variáveis obrigatórias:
  - `DYNAMO_TABLE` — nome exato da tabela; definido pelo Terraform para todos os Lambdas.

## Desenvolvimento
1. Instale dependências locais: `python3 -m pip install -r requirements-dev.txt`.
2. Rode lint + testes: `make test`.
3. Gere zips e aplique infra: `make tf-plan && make tf-apply` dentro de `terraform/`.
4. Para testes rápidos da API, invoque `lambda_src/api/lambda_function.py` localmente simulando o evento do API Gateway ou use `test_awscurl.sh`.

## Próximos passos comuns
- Ajustar políticas IAM/Tags conforme o ambiente.
- Configurar notificações ou métricas adicionais na Step Function.
- Expandir `tests/` cobrindo os fluxos críticos descritos em `documentation.md`.
