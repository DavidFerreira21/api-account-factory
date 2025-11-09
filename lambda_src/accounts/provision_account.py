import logging
import os
import boto3
from datetime import datetime, timezone
from time import sleep
import json


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


dynamo_client = boto3.client("dynamodb")
SC = boto3.client("servicecatalog")
# padroniza variável de ambiente
DYNAMO_TABLE = os.environ.get("DYNAMO_TABLE")
if not DYNAMO_TABLE:
    raise RuntimeError("Missing required environment variable DYNAMO_TABLE")
PRINCIPAL_ARN = os.environ.get("PRINCIPAL_ARN")
SLEEP = 10


def get_product_id():
    filters = {"Owner": ["AWS Control Tower"]}
    af_product_name = "AWS Control Tower Account Factory"
    key = "ProductViewSummary"
    try:
        products = SC.search_products_as_admin(Filters=filters)["ProductViewDetails"]
        for item in products:
            if key in item and item[key]["Name"] == af_product_name:
                return item[key]["ProductId"]
    except Exception as e:
        LOGGER.error(f"Erro ao buscar ProductId: {e}")
    return None


def get_portfolio_id(prod_id):
    try:
        portfolios = SC.list_portfolios_for_product(ProductId=prod_id)[
            "PortfolioDetails"
        ]
        for item in portfolios:
            if item.get("ProviderName") == "AWS Control Tower":
                return item["Id"]
    except Exception as e:
        LOGGER.error(f"Erro ao buscar PortfolioId: {e}")
    return None


def get_provisioning_artifact_id(prod_id):
    try:
        artifacts = SC.describe_product_as_admin(Id=prod_id)[
            "ProvisioningArtifactSummaries"
        ]
        return artifacts[-1]["Id"] if artifacts else None
    except Exception as e:
        LOGGER.error(f"Erro ao buscar ProvisioningArtifactId: {e}")
    return None


def generate_input_params(item):
    return [
        {"Key": "SSOUserEmail", "Value": item["SSOUserEmail"]},
        {"Key": "SSOUserFirstName", "Value": item["SSOUserFirstName"]},
        {"Key": "SSOUserLastName", "Value": item["SSOUserLastName"]},
        {"Key": "ManagedOrganizationalUnit", "Value": item["OrgUnit"]},
        {"Key": "AccountName", "Value": item["AccountName"]},
        {"Key": "AccountEmail", "Value": item["AccountEmail"]},
    ]


def generate_provisioned_product_name(params):
    for p in params:
        if p["Key"] == "AccountName":
            return f"AccountLaunch-{p['Value']}"
    return "AccountLaunch-Unknown"


def list_principals_in_portfolio(port_id):
    """List all prinicpals associated with a portfolio"""

    pri_info = list()
    pri_list = list()

    try:
        sc_paginator = SC.get_paginator("list_principals_for_portfolio")
        sc_page_iterator = sc_paginator.paginate(PortfolioId=port_id)
    except Exception as exe:
        LOGGER.error("Unable to get prinicpals list: %s", str(exe))

    for page in sc_page_iterator:
        pri_list += page["Principals"]

    for item in pri_list:
        pri_info.append(item["PrincipalARN"])

    return pri_info


def associate_principal_portfolio(principal, port_id):
    """Associate a pricipal to portfolio if doesn't exist"""

    result = True
    pri_list = list_principals_in_portfolio(port_id)

    if principal not in pri_list:
        try:
            result = SC.associate_principal_with_portfolio(
                PortfolioId=port_id, PrincipalARN=principal, PrincipalType="IAM"
            )
            LOGGER.info(
                "Associated %s to %s. Sleeping %s sec", principal, port_id, SLEEP
            )
            sleep(SLEEP)
        except Exception as exe:
            LOGGER.error("Unable to associate a principal: %s", str(exe))
            result = False

    return result


def get_pp_status(pp_id):
    try:
        result = SC.describe_provisioned_product(Id=pp_id)["ProvisionedProductDetail"]
        return result["Status"], result.get("StatusMessage", "")
    except Exception as e:
        LOGGER.error(f"Erro ao verificar status do produto provisionado: {e}")
        return "ERROR", str(e)


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

    class ProvisionErrorWithData(Exception):
        def __init__(self, message, account_email):
            super().__init__(message)
            self.item = {"account_email": account_email or "desconhecido"}

    try:

        LOGGER.info(f"Event: {event}")
        item = event

        product_id = get_product_id()
        LOGGER.info(f"ProductId: {product_id}")
        port_id = get_portfolio_id(product_id)
        LOGGER.info(f"PortfolioId: {port_id}")
        associate_principal_portfolio(PRINCIPAL_ARN, port_id)
        LOGGER.info(f"Associado principal {PRINCIPAL_ARN} ao portfolio {port_id}")
        artifact_id = get_provisioning_artifact_id(product_id)
        LOGGER.info(f"ProvisioningArtifactId: {artifact_id}")

        if not product_id or not artifact_id:
            raise ProvisionErrorWithData(
                "ProductId ou ArtifactId não encontrados",
                item.get("AccountEmail", "desconhecido"),
            )

        input_params = generate_input_params(item)
        LOGGER.info(f"InputParams: {input_params}")
        prov_prod_name = generate_provisioned_product_name(input_params)
        LOGGER.info(f"ProvisionedProductName: {prov_prod_name}")
        request_id = item["RequestID"]

        response = SC.provision_product(
            ProductId=product_id,
            ProvisioningArtifactId=artifact_id,
            ProvisionedProductName=prov_prod_name,
            ProvisioningParameters=input_params,
            ProvisionToken=str(request_id),
        )
        LOGGER.info(f"ProvisionProductResponse: {response}")
        pp_id = response["RecordDetail"]["ProvisionedProductId"]
        LOGGER.info(f"ProvisionedProductId: {pp_id}")
        status, message = get_pp_status(pp_id)
        LOGGER.info(f"Status: {status}, Message: {message}")

        if status == "UNDER_CHANGE":
            status = "IN_PROCESSING"

        item["Provisioning"] = True
        item["ProvisionedProductId"] = pp_id
        item["PP_Message"] = message
        item["ProvisionedProductName"] = prov_prod_name
        item["Status"] = status
        item["ProductID"] = product_id
        item["ProvisioningArtifactID"] = artifact_id
        item["PRINCIPAL_ARN"] = PRINCIPAL_ARN
        item["PortfolioID"] = port_id

        if status == "ERROR":
            raise ProvisionErrorWithData(
                f"Erro ao provisionar produto: {message}",
                item.get("AccountEmail", "desconhecido"),
            )

        update_fields = {
            "Status": status,
            "ProvisionedProductId": pp_id,
            "ProvisionedProductName": prov_prod_name,
            "ProductID": product_id,
            "ProvisioningArtifactID": artifact_id,
            "PRINCIPAL_ARN": PRINCIPAL_ARN,
            "PortfolioID": port_id,
        }

        response_dynomodb = update_dynamodb_fields_with_timestamp(
            dynamo_client,
            DYNAMO_TABLE,
            "AccountEmail",
            item["AccountEmail"],
            update_fields,
        )

        LOGGER.info(f"Response DynamoDB: {response_dynomodb}")
        LOGGER.info("Status atualizado para IN_PROCESSING")

        return item

    except Exception as e:
        raise Exception(
            json.dumps(
                {
                    "errorType": "ProvisionError",
                    "errorMessage": str(e),
                    "account_email": item.get("AccountEmail", "desconhecido"),
                }
            )
        )
