import logging
import re
import boto3
import os
import json


# ---------------- Logging ----------------
LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

# ---------------- Clients AWS ----------------
ORG = boto3.client("organizations")
DYNO = boto3.client("dynamodb")
# padroniza variável de ambiente para o nome da tabela
DYNAMO_TABLE = os.environ.get("DYNAMO_TABLE", "AccountsTable")

# ---------------- Configuração ----------------
REQUIRED_FIELDS = [
    "AccountName",
    "AccountEmail",
    "OrgUnit",
    "SSOUserEmail",
    "SSOUserFirstName",
    "SSOUserLastName",
    "RequestID",
]

EMAIL_REGEX = r"^[\w\.-]+@[\w\.-]+\.\w+$"


# ---------------- Funções auxiliares ----------------
def is_valid_email(email):
    return re.match(EMAIL_REGEX, email) is not None


def normalize_item(item):
    """Coloca AccountEmail, SSOUserEmail e AccountName em lowercase e first letter maiúscula para nomes"""
    item["AccountEmail"] = item["AccountEmail"].lower()
    item["SSOUserEmail"] = item["SSOUserEmail"].lower()
    item["AccountName"] = item["AccountName"].lower()
    item["SSOUserFirstName"] = item["SSOUserFirstName"].capitalize()
    item["SSOUserLastName"] = item["SSOUserLastName"].capitalize()
    return item


def check_existing_account(account_name, account_email):
    """Verifica se já existe na AWS Organizations"""
    try:
        paginator = ORG.get_paginator("list_accounts")
        for page in paginator.paginate():
            for acct in page["Accounts"]:
                if (
                    acct["Name"].lower() == account_name
                    or acct["Email"].lower() == account_email
                ):
                    LOGGER.info(
                        f"Conta já existe na Organizations: {account_name} / {account_email}"
                    )
                    return True
    except Exception as e:
        LOGGER.error(f"Erro ao consultar AWS Organizations: {e}")
    return False


def already_processed(account_email):
    """Verifica se já foi processado ou está em andamento no DynamoDB"""
    try:
        response = DYNO.get_item(
            TableName=DYNAMO_TABLE, Key={"AccountEmail": {"S": account_email.lower()}}
        )
        item = response.get("Item", {})
        status = item.get("Status", {}).get("S")
        if status and status != "Requested":
            LOGGER.info(
                f"Item já processado ou em andamento: {account_email} com status {status}"
            )
            return True
    except Exception as e:
        LOGGER.error(f"Erro ao verificar duplicidade no DynamoDB: {e}")
    return False


# ---------------- Lambda Handler ----------------


class ValidationErrorWithData(Exception):
    def __init__(self, message, account_email):
        super().__init__(message)
        self.item = {"account_email": account_email or "desconhecido"}


def lambda_handler(event, context):
    item = event

    try:
        # Campos obrigatórios
        missing_fields = [f for f in REQUIRED_FIELDS if f not in item]
        if missing_fields:
            raise ValidationErrorWithData(
                f"Campos obrigatórios ausentes: {', '.join(missing_fields)}",
                item.get("AccountEmail", "desconhecido"),
            )

        # Normaliza
        item = normalize_item(item)

        # Valida emails
        if not is_valid_email(item["AccountEmail"]) or not is_valid_email(
            item["SSOUserEmail"]
        ):
            raise ValidationErrorWithData(
                "Formato de e-mail inválido", item.get("AccountEmail", "desconhecido")
            )

        # Checa duplicidade na Organizations
        if check_existing_account(item["AccountName"], item["AccountEmail"]):
            raise ValidationErrorWithData(
                "AccountName ou AccountEmail já existem na Organizations",
                item.get("AccountEmail", "desconhecido"),
            )

        # Checa duplicidade no DynamoDB
        if already_processed(item["AccountEmail"]):
            raise ValidationErrorWithData(
                "Item já foi processado ou está em andamento",
                item.get("AccountEmail", "desconhecido"),
            )

        # Sucesso
        LOGGER.info(f"Item validado com sucesso: {item}")
        item["Validation"] = True
        return item

    except ValidationErrorWithData as e:
        # Erros de validação controlados
        raise Exception(
            json.dumps(
                {
                    "errorType": "ValidationErrorWithData",
                    "errorMessage": str(e),
                    "account_email": item.get("AccountEmail", "desconhecido"),
                }
            )
        )

    except Exception as e:
        # Erros inesperados
        raise Exception(
            json.dumps(
                {
                    "errorType": "UnexpectedError",
                    "errorMessage": str(e),
                    "account_email": item.get("AccountEmail", "desconhecido"),
                }
            )
        )
