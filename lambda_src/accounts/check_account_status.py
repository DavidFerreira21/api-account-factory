import logging
import boto3
import json

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

SC = boto3.client("servicecatalog")


def get_pp_status(pp_id):
    """Retorna o status atual do Provisioned Product e mensagem de erro (se houver)."""
    try:
        result = SC.describe_provisioned_product(Id=pp_id)["ProvisionedProductDetail"]
        status = result["Status"]
        message = result.get("StatusMessage", "")
        return status, message
    except Exception as e:
        LOGGER.error(f"Erro ao consultar Service Catalog: {e}")
        return "ERROR", str(e)


def lambda_handler(event, context):

    class CheckStatusErrorWithData(Exception):
        def __init__(self, message, account_email):
            super().__init__(message)
            self.item = {"account_email": account_email or "desconhecido"}

    try:
        item = event
        pp_id = item.get("ProvisionedProductId")

        if not pp_id:
            raise CheckStatusErrorWithData(
                "ProvisionedProductId_id não fornecido no evento",
                item.get("AccountEmail", "desconhecido"),
            )

        sc_status, sc_message = get_pp_status(pp_id)
        LOGGER.info(f"ProvisionedProductId: {pp_id} Status SC={sc_status}")

        # Atualiza o status apenas se diferente de UNDER_CHANGE
        if sc_status != "UNDER_CHANGE":
            item["Status"] = sc_status

        if sc_status == "ERROR":
            raise CheckStatusErrorWithData(
                f"Erro ao provisionar produto: {sc_message}",
                item.get("AccountEmail", "desconhecido"),
            )
        item["CheckStatus"] = True
        return item

    except Exception as e:
        LOGGER.error(f"Erro no CheckAccountStatus: {e}")
        raise Exception(
            json.dumps(
                {
                    "errorType": "CheckStatusError",
                    "errorMessage": str(e),
                    "account_email": item.get("AccountEmail", "desconhecido"),
                }
            )
        )
