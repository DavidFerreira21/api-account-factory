import logging
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

ORG = boto3.client("organizations")
DDB = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("DYNAMO_TABLE")
if not TABLE_NAME:
    raise RuntimeError("Missing required environment variable DYNAMO_TABLE")

TABLE = DDB.Table(TABLE_NAME)
OU_CACHE = {}
ROOT_NAME = ""


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ensure_ou_cache():
    global ROOT_NAME
    if OU_CACHE:
        return

    roots = ORG.list_roots().get("Roots", [])
    if not roots:
        LOGGER.warning("Nenhum root encontrado na organização.")
        return

    root = roots[0]
    ROOT_NAME = root["Name"]
    queue = [(root["Id"], ROOT_NAME)]
    OU_CACHE[root["Id"]] = ROOT_NAME

    paginator = ORG.get_paginator("list_organizational_units_for_parent")
    while queue:
        parent_id, parent_path = queue.pop(0)
        for page in paginator.paginate(ParentId=parent_id):
            for ou in page.get("OrganizationalUnits", []):
                path = f"{parent_path}/{ou['Name']}"
                OU_CACHE[ou["Id"]] = path
                queue.append((ou["Id"], path))


def _get_ou_path(account_id: str) -> str:
    _ensure_ou_cache()
    try:
        parents = ORG.list_parents(ChildId=account_id).get("Parents", [])
        if not parents:
            return ROOT_NAME or "unknown"
        parent = parents[0]
        if parent["Type"] == "ROOT":
            return OU_CACHE.get(parent["Id"], ROOT_NAME or "unknown")
        return OU_CACHE.get(parent["Id"], "unknown")
    except ClientError as error:
        LOGGER.warning("Não foi possível obter OU da conta %s: %s", account_id, error)
        return ROOT_NAME or "unknown"


def _normalize(account, ou_path):
    email = account["Email"].lower()
    timestamp = account.get("JoinedTimestamp")
    joined_at = timestamp.isoformat() if timestamp else _iso_now()
    return {
        "AccountEmail": email,
        "AccountName": account["Name"],
        "AccountId": account["Id"],
        "Status": account["Status"],
        "OrgUnit": ou_path,
        "SSOUserEmail": "",
        "SSOUserFirstName": "",
        "SSOUserLastName": "",
        "RequestID": f"bootstrap-{account['Id']}",
        "CreatedAt": joined_at,
        "UpdatedAt": _iso_now(),
        "LastUpdateDate": _iso_now(),
    }


def _fetch_tags(account_id):
    try:
        response = ORG.list_tags_for_resource(ResourceId=account_id)
        return [
            {"Key": tag["Key"], "Value": tag["Value"]}
            for tag in response.get("Tags", [])
        ]
    except ClientError as error:
        LOGGER.warning("Não foi possível obter tags para %s: %s", account_id, error)
        return []


def lambda_handler(event, context):
    LOGGER.info("Iniciando bootstrap de contas do Organizations para %s", TABLE_NAME)
    paginator = ORG.get_paginator("list_accounts")
    processed = 0
    failures = 0
    for page in paginator.paginate():
        for account in page.get("Accounts", []):
            path = _get_ou_path(account["Id"])
            item = _normalize(account, path)
            tags = _fetch_tags(account["Id"])
            try:
                TABLE.update_item(
                    Key={"AccountEmail": item["AccountEmail"]},
                    UpdateExpression=(
                        "SET AccountName = :name, "
                        "AccountId = :accId, "
                        "Status = :status, "
                        "OrgUnit = :org, "
                        "SSOUserEmail = if_not_exists(SSOUserEmail, :ssoEmail), "
                        "SSOUserFirstName = if_not_exists(SSOUserFirstName, :ssoFirst), "
                        "SSOUserLastName = if_not_exists(SSOUserLastName, :ssoLast), "
                        "RequestID = if_not_exists(RequestID, :req), "
                        "UpdatedAt = :updated, "
                        "LastUpdateDate = :updated, "
                        "Tags = :tags, "
                        "CreatedAt = if_not_exists(CreatedAt, :created)"
                    ),
                    ExpressionAttributeValues={
                        ":name": item["AccountName"],
                        ":accId": item["AccountId"],
                        ":status": item["Status"],
                        ":org": item["OrgUnit"],
                        ":req": item["RequestID"],
                        ":updated": _iso_now(),
                        ":created": item["CreatedAt"],
                        ":tags": tags,
                        ":ssoEmail": item["SSOUserEmail"],
                        ":ssoFirst": item["SSOUserFirstName"],
                        ":ssoLast": item["SSOUserLastName"],
                    },
                )
                processed += 1
            except ClientError as error:
                failures += 1
                LOGGER.error("Falha ao gravar %s: %s", item["AccountEmail"], error)

    LOGGER.info("Bootstrap finalizado. Gravados: %s, falhas: %s", processed, failures)
    return {"inserted": processed, "failed": failures}
