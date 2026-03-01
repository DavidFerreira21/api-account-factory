"""Bootstrap existing AWS Organizations accounts into DynamoDB.

Runs an initial/on-demand sync to populate or refresh metadata
for accounts that already exist in the organization.
"""

import logging
import os
import time
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
MAX_IAM_PROPAGATION_RETRIES = 6
MAX_REPORTED_ERRORS = 10


def _to_bool(value, default=False):
    """Convert generic values to boolean."""
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    return bool(value)


def _iter_accounts_pages():
    """Return account pages with retry/backoff for IAM propagation."""
    paginator = ORG.get_paginator("list_accounts")
    delay_seconds = 2
    for attempt in range(1, MAX_IAM_PROPAGATION_RETRIES + 1):
        try:
            return paginator.paginate()
        except ClientError as error:
            code = error.response.get("Error", {}).get("Code")
            if (
                code != "AccessDeniedException"
                or attempt == MAX_IAM_PROPAGATION_RETRIES
            ):
                raise
            LOGGER.warning(
                "AccessDenied em organizations:ListAccounts (tentativa %s/%s). "
                "Aguardando %ss para propagação IAM.",
                attempt,
                MAX_IAM_PROPAGATION_RETRIES,
                delay_seconds,
            )
            time.sleep(delay_seconds)
            delay_seconds *= 2


def _iso_now() -> str:
    """Generate UTC timestamp in ISO-8601 format."""
    return datetime.now(timezone.utc).isoformat()


def _ensure_ou_cache():
    """Build an in-memory OU path cache to reduce repeated API calls."""
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
    """Resolve account OU path and return a default value on failure."""
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
    """Normalize account metadata to DynamoDB storage format."""
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
    """Fetch account tags from Organizations with pagination."""
    try:
        paginator = ORG.get_paginator("list_tags_for_resource")
        tags = []
        for page in paginator.paginate(ResourceId=account_id):
            tags.extend(
                {"Key": tag["Key"], "Value": tag["Value"]}
                for tag in page.get("Tags", [])
            )
        return tags
    except ClientError as error:
        LOGGER.warning("Não foi possível obter tags para %s: %s", account_id, error)
        return []


def lambda_handler(event, context):
    """Bootstrap entry point triggered by Terraform action/manual invoke."""
    event = event or {}
    LOGGER.info("Iniciando bootstrap de contas do Organizations para %s", TABLE_NAME)
    processed = 0
    failures = 0
    failed_accounts = []
    fail_on_partial = _to_bool(event.get("fail_on_partial"), default=False)
    try:
        account_pages = _iter_accounts_pages()
    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "Unknown")
        raise RuntimeError(
            "Falha ao listar contas no Organizations. "
            "Verifique se a role da Lambda tem organizations:ListAccounts e se a conta "
            "de execução pode consultar a Organization (management account/SCP). "
            f"AWS ErrorCode={code}"
        ) from error

    for page in account_pages:
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
                        "#status = :status, "
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
                    ExpressionAttributeNames={
                        "#status": "Status",
                    },
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
                if len(failed_accounts) < MAX_REPORTED_ERRORS:
                    failed_accounts.append(
                        {
                            "account_email": item["AccountEmail"],
                            "error_code": error.response.get("Error", {}).get(
                                "Code", "Unknown"
                            ),
                            "message": error.response.get("Error", {}).get(
                                "Message", str(error)
                            ),
                        }
                    )

    LOGGER.info("Bootstrap finalizado. Gravados: %s, falhas: %s", processed, failures)
    if failures > 0 and fail_on_partial:
        raise RuntimeError(
            f"Bootstrap finalizado com falhas. Gravados: {processed}, falhas: {failures}"
        )
    if failures > 0:
        LOGGER.warning(
            "Bootstrap com falhas parciais (modo nao bloqueante). Primeiros erros: %s",
            failed_accounts,
        )
    return {"inserted": processed, "failed": failures, "errors": failed_accounts}
