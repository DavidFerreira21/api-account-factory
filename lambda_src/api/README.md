# Lambda — API (lambda_src/api)

Este README descreve como testar e entender a Lambda `lambda_function.py` que implementa a API.

Entry point
- Handler: `lambda_function.lambda_handler`
- Recebe eventos no formato de API Gateway (proxy integration): `httpMethod`, `queryStringParameters`, `body`.

Comportamento suportado
- GET /getAccount — parâmetros de query: `accountEmail` ou `accountId`
- POST /createAccount — body JSON com os campos obrigatórios descritos abaixo

Campos obrigatórios no POST
- AccountEmail
- AccountName
- OrgUnit
- SSOUserEmail
- SSOUserFirstName
- SSOUserLastName

Resposta e códigos HTTP
- 201 — criação bem sucedida (item gravado em DynamoDB)
- 400 — erro no payload (JSON inválido ou campos faltando)
- 404 — item não encontrado (GET)
- 409 — conflito (ex.: AccountName/AccountEmail já existe)
- 500 — erro interno

Variáveis de ambiente
- `DYNAMO_TABLE` (obrigatório; informe o nome da tabela DynamoDB)

Testando localmente (exemplos)
- Executar a função localmente com um script Python que importe o handler e passe um evento simulado.

Exemplo rápido (Python):

```python
from lambda_src.api.lambda_function import lambda_handler

event = {
  "httpMethod": "POST",
  "body": json.dumps({
      "AccountEmail": "user@example.com",
      "AccountName": "my-new-account",
      "OrgUnit": "Engineering",
      "SSOUserEmail": "owner@example.com",
      "SSOUserFirstName": "Jean",
      "SSOUserLastName": "Dupont"
  })
}

print(lambda_handler(event, None))
```

Observações de desenvolvimento
- As chamadas para AWS (DynamoDB, Organizations) usam `boto3`. Para testes unitários, mocar `boto3`/`table` e `org_client`.
- Há funções utilitárias em `lambda_src/accounts` que fazem parte do fluxo completo de provisionamento.

Próximos passos recomendados
- Criar `pytest` cobrindo:
  - POST happy path (mock DynamoDB put_item)
  - POST com campos faltando (verificar 400)
  - GET com `accountEmail` inexistente (404)
- Adicionar um `Makefile` com comandos úteis (test, lint, fmt) para desenvolvedores.
