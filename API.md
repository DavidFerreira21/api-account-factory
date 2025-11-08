# 🧩 Automação de Criação de Contas AWS – Accounts API

Esta documentação descreve a API e os componentes serverless (Dynamodb, Lambdas e Step Function) que permitem solicitar, orquestrar e acompanhar a criação de contas AWS dentro de uma organização (Control Tower / Account Factory).

Objetivo
- Expor um endpoint HTTP simples para receber requisições de criação de conta na AWS
- Persistir a solicitação em DynamoDB e iniciar uma Step Function que faz as validações e o provisioning
- Notificar e atualizar o status no DynamoDB até a conclusão (Provisioned) ou falha (Failed)

---

## 1. Endpoints da API

Base: API Gateway → Lambda (`lambda_src/api/lambda_function.py`).

1) POST /createAccount
- Descrição: cria uma nova solicitação de criação de conta. Valida o payload e, se válido, grava um item com Status=`Requested` na tabela DynamoDB.
- Body: JSON (application/json)

Exemplo de body com OU de primeiro nível:
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

Exemplo com sub-OU (usando caminho completo):
```json
{
  "AccountEmail": "platform@example.com",
  "AccountName": "platform-dev",
  "OrgUnit": "Engineering/Platform/Dev",  
  "SSOUserEmail": "admin@example.com",
  "SSOUserFirstName": "Maria",
  "SSOUserLastName": "Silva",
  "Tags": [{"Key":"team","Value":"platform"}]
}
```

Respostas comuns:
- 201 Created — item gravado em DynamoDB (body contém o item criado)
- 400 Bad Request — JSON inválido ou campos obrigatórios faltando
- 409 Conflict — account/email/AccountName já existe
- 500 Internal Server Error — erro interno

2) GET /getAccount
- Descrição: consulta o item na tabela DynamoDB por `accountEmail` (recomendado) ou `accountId`.
- Query params: `accountEmail` ou `accountId` (um dos dois é obrigatório)

Respostas comuns:
- 200 OK — retorna o item
- 400 Bad Request — parâmetros ausentes
- 404 Not Found — item não encontrado

### Regras e validações importantes

#### Campos obrigatórios (POST)
- AccountEmail — email da conta AWS
- AccountName — nome da conta
- OrgUnit — caminho completo da OU (ex: "Engineering" ou "Engineering/Platform/Dev")
- SSOUserEmail — email do usuário SSO
- SSOUserFirstName — primeiro nome
- SSOUserLastName — sobrenome

#### Validação de OU
- O campo OrgUnit deve especificar o caminho completo até a OU desejada
- Use "/" como separador para sub-OUs (ex: "Engineering/Platform")
- Exemplos válidos:
  - "Engineering" (OU de primeiro nível)
  - "Engineering/Platform" (sub-OU)
  - "Engineering/Platform/Dev" (sub-sub-OU)
- A validação verifica se a OU existe exatamente no caminho especificado

#### Outras validações
- Emails são convertidos para lowercase antes do armazenamento
- AccountName não pode existir em outra conta
- Nomes (First/LastName) são capitalizados
- Gravações no DynamoDB usam ConditionExpression para evitar sobrescrita

---

## 2. DynamoDB — tabela `AccountsTable` (modelo de dados)

Chave primária: `AccountEmail` (string, lowercase)

Campos principais (exemplo de tipos):
- AccountEmail (PK) — string
- AccountName — string
- SSOUserEmail — string
- SSOUserFirstName — string
- SSOUserLastName — string
- OrgUnit — string (caminho completo da OU, ex: "Engineering/Platform")
- Status — string (enum: Requested, Valid, InProgress, Provisioned, Failed)
- AccountId — string (preenchido após provisionamento)
- ErrorMessage — string (opcional)
- RequestID — string (UUID)
- CreatedAt — string (ISO8601)
- UpdatedAt — string (ISO8601)
- LastUpdateDate — string (ISO8601)
- Tags — list(map)

Observações:
- O código atual usa `CreatedAt`, `UpdatedAt` e `LastUpdateDate` em ISO8601. Garanta consistência na leitura/escrita.


---

## 3. Lambdas (papéis e triggers)

Esta seção descreve cada Lambda usada no fluxo e seu propósito, entrada/saída e variáveis de ambiente relevantes.

1) lambda_src/api/lambda_function.py (API Handler)
- Trigger: API Gateway (proxy integration)
- Funções: GET /getAccount, POST /createAccount
- Dependências: boto3 (DynamoDB, Organizations)
- Variáveis: `DYNAMO_TABLE` (opcional, default `AccountsTable`)

2) Trigger Step Function — `lambda_src/accounts/trigger_sfn.py`
- Trigger: DynamoDB Streams (evento INSERT)
- Propósito: ouvir inserts na tabela `AccountsTable` e, para itens com `Status == 'Requested'`, iniciar a Step Function passando o conteúdo do `NewImage`.
- Variáveis/Config:
  - `SFN_ARN` (obrigatório) — ARN da Step Function a ser iniciada
- Comportamento:
  - Ignora eventos que não são `INSERT`.
  - Constrói um payload plano a partir do `NewImage` (conversão de atributos DynamoDB para valores primitivos) e chama `start_execution`.
- Permissões necessárias:
  - `states:StartExecution` na Step Function
  - `logs` para registrar informações

3) Validate (validação inicial)
- Trigger: Step Function (invocado no começo do fluxo)
- Função: valida campos do payload, verifica OU via Organizations, valida disponibilidade de AccountName/Email.

4) ProvisionAccount
- Trigger: Step Function
- Função: inicia provisionamento via Service Catalog / Account Factory (ou chama outro componente que o faça) e atualiza status para `InProgress`.

5) CheckAccountStatus
- Trigger: Step Function (loop com Wait)
- Função: checa se o provisionamento terminou (Provisioned) ou falhou (Failed) e retorna um resultado que determina o fluxo.

6) UpdateStatus (Update succeed)
- Trigger: Step Function (no final, quando Provisioned)
- Função: atualiza o item no DynamoDB salvando `AccountId`, atualiza `Status` para `Provisioned` e registra timestamps.

Exemplo (sem formatação DynamoDB): payload enviado à Step Function será um JSON com os campos do item (AccountEmail, AccountName, ...).

7) UpdateFailedStatus — `lambda_src/accounts/update_failed_status.py`
- Trigger: Step Function (nó de erro / catch) ou Step Function passando um objeto de erro
- Propósito: em caso de falha na validação ou provisionamento, extrair o `account_email` do objeto de erro e remover (ou atualizar) o item no DynamoDB. Esse Lambda também registra a falha para auditoria.
- Variáveis/Config:
  - `DYNAMO_TABLE` (obrigatório) — nome da tabela DynamoDB (use `DYNAMO_TABLE` em todas as Lambdas)
- Comportamento observado no código:
  - Tenta extrair `account_email` do objeto `event["Error"]`/`Cause` e faz `delete_item` na tabela.
  - Retorna um objeto com `success` e `account_email` quando bem sucedido.
- Permissões necessárias:
  - `dynamodb:DeleteItem` na tabela `AccountsTable`
  - `logs:Write`

Observação de segurança: deletar o item diretamente em caso de falha é uma decisão operacional — você pode preferir atualizar o item com `Status=Failed` e salvar um `ErrorMessage` em vez de remover o registro para fins de auditoria.

---

## 4. Step Function — visão geral do fluxo

Resumo do fluxo `Create-Account`:
1. DynamoDB INSERT ocorre (Status=`Requested`) → `trigger_sfn` (DynamoDB Stream) inicia a Step Function com o payload do item.
2. Step Function: Validate → ProvisionAccount → Wait (loop) → CheckAccountStatus → UpdateStatus/UpdateFailedStatus

Recomendações de tempo e retries:
- Ajuste do `Wait` e número de retries no Step Function conforme SLA de provisionamento.
- Use mecanismos de backoff exponencial e captura de erros (`Catch`) para acionar `update_failed_status` e notificar times responsáveis.

---

## 5. Permissões IAM (resumo)
- Lambda API: acesso a DynamoDB (GetItem/Scan/PutItem) e Organizations (ListRoots, ListOrganizationalUnitsForParent).
- trigger_sfn: `states:StartExecution`.
- update_failed_status: `dynamodb:DeleteItem` (ou `UpdateItem` se optar por marcar Failed), `dynamodb:GetItem` se necessário.

---


```mermaid
flowchart LR

%% API
subgraph API[API]
    getAccount[🔍 GET /getAccount] --> validaParametros[✅ Validar Parâmetros]
    createAccount[📝 POST /createAccount] --> validaPayload[✅ Validar Payload]
end

%% Consulta
subgraph Consulta[Consulta]
    validaParametros --> consultaDynamo[📂 Consultar DynamoDB]
    consultaDynamo --> retornaDados[📤 Retornar dados]
end

%% Criação
subgraph Criação[Criação de Conta]
    validaPayload -->|Payload Válido| gravaDynamo[🗄️ Gravar no DynamoDB]
    validaPayload -->|Payload Inválido| retornoErro[❌ Retornar erro ao usuário]
    gravaDynamo --> requisicaoCriada[📤 Retornar: Requisição criada]
    gravaDynamo --> streamDynamo[🔁 DynamoDB Streams]
    streamDynamo --> stepFunction[🧩 Step Function]
end

%% Step Function
subgraph StepFunction[Step Function – Create-Account]
    stepValidate[1️⃣ Validate] --> stepProvision[2️⃣ ProvisionAccount]
    stepProvision --> wait5[3️⃣ Wait 5 min]
    wait5 --> stepCheck[4️⃣ CheckAccountStatus]
    stepCheck -->|InProgress| wait5
    stepCheck -->|Provisioned / Failed| stepUpdate[5️⃣ UpdateStatus]
end

stepFunction --> StepFunction
