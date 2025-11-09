import json
import boto3
import os
import uuid
import logging
from datetime import datetime
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Attr

# Logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
dynamodb = boto3.resource("dynamodb")
org_client = boto3.client("organizations")

TABLE_NAME = os.environ.get("DYNAMO_TABLE")
if not TABLE_NAME:
    raise RuntimeError("Missing required environment variable DYNAMO_TABLE")
table = dynamodb.Table(TABLE_NAME)


def format_name(name):
    """Formata nomes com capitalização"""
    return " ".join([part.capitalize() for part in name.strip().split()])


def lambda_handler(event, context):
    method = event.get("httpMethod")
    logger.info(f"HTTP Method: {method}")
    logger.info(f"Event received: {json.dumps(event)}")

    if method == "GET":
        params = event.get("queryStringParameters") or {}
        account_email = params.get("accountEmail")
        account_id = params.get("accountId")
        return get_account(account_email, account_id)

    elif method == "POST":
        try:
            body = json.loads(event.get("body", "{}"))
        except json.JSONDecodeError:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Invalid JSON format"}),
            }

        # Valida campos obrigatórios
        required_fields = [
            "AccountEmail",
            "AccountName",
            "OrgUnit",
            "SSOUserEmail",
            "SSOUserFirstName",
            "SSOUserLastName",
        ]
        missing = [f for f in required_fields if f not in body or not body[f]]
        if missing:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": f"Missing fields: {', '.join(missing)}"}),
            }

        # Formata nomes
        body["SSOUserFirstName"] = format_name(body["SSOUserFirstName"])
        body["SSOUserLastName"] = format_name(body["SSOUserLastName"])

        return create_account(body)

    else:
        return {"statusCode": 405, "body": json.dumps({"error": "Method not allowed"})}


# ---------------- GET ----------------
def get_account(account_email=None, account_id=None):
    try:
        if account_email:
            response = table.get_item(
                Key={"AccountEmail": account_email.strip().lower()}
            )
            item = response.get("Item")
            if not item:
                return {
                    "statusCode": 404,
                    "body": json.dumps({"error": "Account not found"}),
                }
            return {"statusCode": 200, "body": json.dumps(item)}

        elif account_id:
            response = table.scan(FilterExpression=Attr("AccountId").eq(account_id))
            items = response.get("Items", [])
            if not items:
                return {
                    "statusCode": 404,
                    "body": json.dumps({"error": "Account not found"}),
                }
            return {"statusCode": 200, "body": json.dumps(items[0])}

        else:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Provide accountEmail or accountId"}),
            }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}


# ---------------- POST ----------------
def create_account(data):
    if not validate_account_name(data["AccountName"]):
        return {
            "statusCode": 409,
            "body": json.dumps({"error": "AccountName already exists"}),
        }
    if not validate_org_unit(data["OrgUnit"]):
        return {
            "statusCode": 400,
            "body": json.dumps({"error": f"Invalid OrgUnit: {data['OrgUnit']}"}),
        }

    request_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()

    item = {
        "AccountEmail": data["AccountEmail"].strip().lower(),
        "AccountName": data["AccountName"].strip(),
        "SSOUserEmail": data["SSOUserEmail"].strip().lower(),
        "SSOUserFirstName": data["SSOUserFirstName"],
        "SSOUserLastName": data["SSOUserLastName"],
        "OrgUnit": data["OrgUnit"],
        "Status": "Requested",
        "RequestID": request_id,
        "CreatedAt": timestamp,
        "UpdatedAt": timestamp,
        "LastUpdateDate": timestamp,
    }

    if "Tags" in data:
        item["Tags"] = data["Tags"]

    try:
        table.put_item(
            Item=item, ConditionExpression="attribute_not_exists(AccountEmail)"
        )
        return {"statusCode": 201, "body": json.dumps(item)}
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return {
                "statusCode": 409,
                "body": json.dumps({"error": "Account already exists"}),
            }
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}


# ---------------- Validation ----------------
def validate_org_unit(ou_path):
    """
    Valida se uma OU existe seguindo o caminho especificado (ex: "Engineering/Platform").
    Retorna True se encontrar a OU exata no caminho especificado.
    """
    try:
        # Pega o root como ponto de partida
        roots = org_client.list_roots()
        if not roots.get("Roots"):
            logger.error("Nenhum root encontrado na organização")
            return False

        current_parent_id = roots["Roots"][0]["Id"]
        ou_parts = [part.strip() for part in ou_path.split("/") if part.strip()]

        # Para cada parte do caminho (Engineering, depois Platform, etc)
        for ou_name in ou_parts:
            found = False
            paginator = org_client.get_paginator("list_organizational_units_for_parent")

            # Lista OUs do nível atual
            for page in paginator.paginate(ParentId=current_parent_id):
                for ou in page["OrganizationalUnits"]:
                    if ou["Name"].lower() == ou_name.lower():
                        current_parent_id = ou["Id"]  # Move para próximo nível
                        found = True
                        break
                if found:
                    break

            # Se não achou alguma parte do caminho, OU não existe
            if not found:
                logger.warning(
                    f"OU não encontrada no caminho: {ou_path} (parou em: {ou_name})"
                )
                return False

        # Se chegou aqui, encontrou todo o caminho
        return True

    except Exception as e:
        logger.error(f"Erro ao validar OU path '{ou_path}': {str(e)}")
        return False


def validate_account_name(account_name):
    try:
        response = table.scan(
            FilterExpression=Attr("AccountName").eq(account_name.strip().lower())
        )
        return len(response.get("Items", [])) == 0
    except Exception:
        return False
