import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SFN_ARN = os.environ["SFN_ARN"]
sfn_client = boto3.client("stepfunctions")


def lambda_handler(event, context):
    for record in event.get("Records", []):
        try:
            # Confirma que é insert e status é Requested
            if record["eventName"] != "INSERT":
                continue

            new_image = record["dynamodb"]["NewImage"]
            status = new_image.get("Status", {}).get("S")
            if status != "Requested":
                continue

            # Monta payload para Step Function
            payload = {k: list(v.values())[0] for k, v in new_image.items()}
            logger.info(f"Starting Step Function with payload: {payload}")

            response = sfn_client.start_execution(
                stateMachineArn=SFN_ARN, input=json.dumps(payload)
            )
            logger.info(f"Step Function started: {response['executionArn']}")

        except Exception as e:
            logger.error(f"Error processing record: {e}")

    return {"Status": "processed"}
