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
AWS_REGION="${AWS_REGION:-us-east-1}"
REST_API_ID="${REST_API_ID:-mez04uhsgk}"
API_STAGE="${API_STAGE:-prod}"
API_RESOURCE_PATH="${API_RESOURCE_PATH:-/accounts}"

# Variáveis de teste
MODE="post"                              # Valores aceitos: post | get (override com flag)
ACCOUNT_EMAIL=""
ACCOUNT_ID=""

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
PAYLOAD_FILE=""

usage() {
  cat <<EOF
Uso: $(basename "$0") [-m post|get] [--email foo@bar.com] [--id 123456789012] [--payload path.json]
Flags:
  -m, --mode        post (default) ou get
  -e, --email       e-mail para consulta (GET). Se omitido, usa o campo AccountEmail do payload.
  -i, --id          accountId para consulta (GET). Se omitido, usa o campo AccountId do payload (se existir).
  -p, --payload     caminho para JSON (objeto único ou lista com até 5 itens)
  -h, --help        mostra esta mensagem
Também é possível definir variáveis via env (AWS_REGION, REST_API_ID, API_STAGE, API_RESOURCE_PATH).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode)
      MODE="$2"; shift 2;;
    -e|--email)
      ACCOUNT_EMAIL="$2"; shift 2;;
    -i|--id)
      ACCOUNT_ID="$2"; shift 2;;
    -p|--payload)
      PAYLOAD_FILE="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Flag desconhecida: $1" >&2
      usage
      exit 1;;
  esac
done

if [[ -n "${PAYLOAD_FILE}" ]]; then
  if ! mapfile -t PAYLOAD_BATCH < <(python3 - "$PAYLOAD_FILE" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
if isinstance(data, dict):
    data = [data]
if not isinstance(data, list):
    raise SystemExit("Payload deve ser um objeto único ou lista de objetos")
for item in data[:5]:
    print(json.dumps(item, ensure_ascii=False))
PY
); then
    echo "Erro ao ler payload de ${PAYLOAD_FILE}. Verifique se é JSON válido." >&2
    exit 1
  fi
else
  PAYLOAD_BATCH=("${PAYLOAD_JSON}")
fi

API_HOST="${REST_API_ID}.execute-api.${AWS_REGION}.amazonaws.com"
API_URL="https://${API_HOST}/${API_STAGE}${API_RESOURCE_PATH}"

case "${MODE}" in
  post)
    for payload in "${PAYLOAD_BATCH[@]}"; do
      echo "Enviando POST para ${API_URL} na região ${AWS_REGION}"
      awscurl \
        --region "${AWS_REGION}" \
        --service execute-api \
        --request POST \
        --header "Content-Type: application/json" \
        --data "${payload}" \
        "${API_URL}"
    done
    ;;
  get)
    if [[ -z "${ACCOUNT_EMAIL}" && -z "${ACCOUNT_ID}" && -n "${PAYLOAD_BATCH[0]}" ]]; then
      ACCOUNT_EMAIL=$(python3 - <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
if isinstance(data, str):
    print(data)
elif isinstance(data, dict):
    print(data.get("AccountEmail", ""))
else:
    print("")
PY
"${PAYLOAD_BATCH[0]}")
    fi

    if [[ -n "${ACCOUNT_EMAIL}" ]]; then
      QUERY_STRING="accountEmail=${ACCOUNT_EMAIL}"
      echo "Consultando status via GET para accountEmail=${ACCOUNT_EMAIL}"
    elif [[ -n "${ACCOUNT_ID}" ]]; then
      QUERY_STRING="accountId=${ACCOUNT_ID}"
      echo "Consultando status via GET para accountId=${ACCOUNT_ID}"
    else
      echo "Forneça um e-mail ou accountId (via flag ou no payload) para usar o GET." >&2
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
