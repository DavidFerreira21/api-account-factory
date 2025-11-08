import json
import logging
import os

import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

DYNO = boto3.client("dynamodb")
DYNAMO_TABLE = os.environ.get("DYNAMO_TABLE", "AccountsTable")


def lambda_handler(event, context):
    try:
        account_email = None
        error_message_str = "{}"

        if "Error" in event:
            validate_error = event.get("Error", {})
            cause_str = validate_error.get("Cause", "{}")
            cause_obj = json.loads(cause_str)
            error_message_str = cause_obj.get("errorMessage", "{}")
            error_data = json.loads(error_message_str)
            account_email = error_data.get("account_email", "desconhecido")
            LOGGER.info(f"Email: {account_email} extraído do erro.")

        DYNO.delete_item(
            TableName=DYNAMO_TABLE,
            Key={"AccountEmail": {"S": account_email}},
        )
        LOGGER.warning(
            f"Falha na criação da conta {account_email}. Item removido do DynamoDB."
        )
        return {
            "Success": "False",
            "account_email": account_email,
            "errorMessage": error_message_str,
            "Status": "Resquest_removed",
        }
    except Exception as e:
        LOGGER.error(f"Erro no UpdateFailedStatusLambda: {e}")
        return {"Success": "False", "error": str(e)}
