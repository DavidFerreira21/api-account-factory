import logging
import os
import boto3
from datetime import datetime, timezone

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

sevicecatalog_client = boto3.client("servicecatalog")
dynamo_client = boto3.client("dynamodb")
# padroniza variável de ambiente para o nome da tabela
DYNAMO_TABLE = os.environ.get("DYNAMO_TABLE")
if not DYNAMO_TABLE:
    raise RuntimeError("Missing required environment variable DYNAMO_TABLE")


def get_account_id(servicecatalog_client, pp_id):
    """
    Busca o AccountId associado ao ProvisionedProductId usando a API get_provisioned_product_outputs.
    """
    try:
        response = servicecatalog_client.get_provisioned_product_outputs(
            ProvisionedProductId=pp_id
        )
        outputs = response.get("Outputs", [])
        for output in outputs:
            if output.get("OutputKey") == "AccountId":
                return output.get("OutputValue")
        LOGGER.warning(f"Output 'AccountId' não encontrado para {pp_id}.")
    except Exception as e:
        LOGGER.error(
            f"Erro ao buscar AccountId via get_provisioned_product_outputs para {pp_id}: {e}"
        )
    return None


def format_dynamo_value(value):
    if isinstance(value, bool):
        return {"BOOL": value}
    elif isinstance(value, (int, float)):
        return {"N": str(value)}
    else:
        return {"S": str(value)}


def update_dynamodb_fields_with_timestamp(
    dynamo_client, table_name, key_field, key_value, update_fields
):
    update_expression_parts = []
    expression_attribute_names = {}
    expression_attribute_values = {}

    for i, (field, value) in enumerate(update_fields.items()):
        placeholder_name = f"#f{i}"
        placeholder_value = f":v{i}"
        update_expression_parts.append(f"{placeholder_name} = {placeholder_value}")
        expression_attribute_names[placeholder_name] = field
        expression_attribute_values[placeholder_value] = format_dynamo_value(value)

    update_expression_parts.append("#LastUpdate = :ts")
    expression_attribute_names["#LastUpdate"] = "LastUpdate"
    expression_attribute_values[":ts"] = {"S": datetime.now(timezone.utc).isoformat()}

    update_expression = "SET " + ", ".join(update_expression_parts)

    return dynamo_client.update_item(
        TableName=table_name,
        Key={key_field: {"S": key_value}},
        UpdateExpression=update_expression,
        ExpressionAttributeNames=expression_attribute_names,
        ExpressionAttributeValues=expression_attribute_values,
    )


def lambda_handler(event, context):

    try:
        # Pega o item com AccountEmail e AccountId
        item = event
        account_email = item.get("AccountEmail")
        pp_id = item.get("ProvisionedProductId")
        account_id = get_account_id(sevicecatalog_client, pp_id)

        if not account_id:
            update_fields = {
                "Status": "ERROR",
                "AccountId": "N/A",
            }
            update_dynamodb_fields_with_timestamp(
                dynamo_client,
                DYNAMO_TABLE,
                "AccountEmail",
                account_email,
                update_fields,
            )
            raise Exception(
                f"AccountId não encontrado para ProvisionedProductId {pp_id}"
            )

        LOGGER.info(
            f"AccountId {account_id} encontrado para ProvisionedProductId {pp_id}"
        )
        # Atualiza DynamoDB como Provisioned
        update_fields = {
            "Status": "ACTIVE",
            "AccountId": account_id,
        }
        update_dynamodb_fields_with_timestamp(
            dynamo_client, DYNAMO_TABLE, "AccountEmail", account_email, update_fields
        )
        LOGGER.info(f"Conta {account_email} atualizada para ACTIVE no DynamoDB.")
        item["AccountId"] = account_id
        item["Status"] = "ACTIVE"
        item["Success"] = "True"
        return item
    except Exception as e:
        LOGGER.error(f"Erro no UpdateStatusLambda: {e}")
        return {"Success": "False", "message": str(e)}
