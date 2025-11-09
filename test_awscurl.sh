#!/usr/bin/env bash
set -euo pipefail

# Pré-requisitos:
# 1) AWS CLI instalado e configurado (`aws configure`) com credenciais que tenham permissão para invocar o API Gateway/Lambda.
# 2) awscurl instalado; exemplo: `python3 -m pip install --user awscurl`.

if ! command -v aws >/dev/null; then
  echo "AWS CLI não encontrado. Instale e configure com 'aws configure' antes de rodar este script." >&2
  exit 1
fi

if ! command -v awscurl >/dev/null; then
  echo "awscurl não encontrado. Instale com 'python3 -m pip install --user awscurl' antes de rodar este script." >&2
  exit 1
fi

# Configurações básicas
AWS_REGION="us-east-1"
REST_API_ID="mez04uhsgk"
API_STAGE="prod"
API_RESOURCE_PATH="/accounts"

# Variáveis de teste
MODE="post"                              # Valores aceitos: post | get
ACCOUNT_EMAIL="conta210@empresa.com"     # Usado no modo GET
ACCOUNT_ID=""                            # Alternativa ao email para GET

# Payload usado no modo POST
PAYLOAD_JSON='{
  "SSOUserEmail": "email210@exemplo.com",
  "SSOUserFirstName": "João",
  "SSOUserLastName": "Silva",
  "OrgUnit": "Sandbox",
  "AccountName": "conta210",
  "AccountEmail": "conta210@empresa.com",
  "Tags": [
    { "Key": "Ambiente", "Value": "Dev" }
  ]
}'

API_HOST="${REST_API_ID}.execute-api.${AWS_REGION}.amazonaws.com"
API_URL="https://${API_HOST}/${API_STAGE}${API_RESOURCE_PATH}"

case "${MODE}" in
  post)
    echo "Enviando POST para ${API_URL} na região ${AWS_REGION}"
    awscurl \
      --region "${AWS_REGION}" \
      --service execute-api \
      --request POST \
      --header "Content-Type: application/json" \
      --data "${PAYLOAD_JSON}" \
      "${API_URL}"
    ;;
  get)
    if [[ -n "${ACCOUNT_EMAIL}" ]]; then
      QUERY_STRING="accountEmail=${ACCOUNT_EMAIL}"
      echo "Consultando status via GET para accountEmail=${ACCOUNT_EMAIL}"
    elif [[ -n "${ACCOUNT_ID}" ]]; then
      QUERY_STRING="accountId=${ACCOUNT_ID}"
      echo "Consultando status via GET para accountId=${ACCOUNT_ID}"
    else
      echo "Configure ACCOUNT_EMAIL ou ACCOUNT_ID para usar o modo GET." >&2
      exit 1
    fi

    awscurl \
      --region "${AWS_REGION}" \
      --service execute-api \
      --request GET \
      "${API_URL}?${QUERY_STRING}"
    ;;
  *)
    echo "Valor inválido para MODE: ${MODE} (use post ou get)" >&2
    exit 1
    ;;
esac
