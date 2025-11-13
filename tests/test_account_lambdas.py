import importlib
import json
import sys
import types
from datetime import datetime, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


if "boto3" not in sys.modules:

    class _DummyDynamoResource:
        def Table(self, name):  # pragma: no cover - only used during import
            return None

    class _DummyClient:
        pass

    dummy_boto3 = types.ModuleType("boto3")
    dummy_boto3.resource = lambda *_args, **_kwargs: _DummyDynamoResource()
    dummy_boto3.client = lambda *_args, **_kwargs: _DummyClient()
    sys.modules["boto3"] = dummy_boto3

if "botocore" not in sys.modules:
    botocore_exceptions = types.SimpleNamespace(ClientError=Exception)
    sys.modules["botocore"] = types.SimpleNamespace(exceptions=botocore_exceptions)
    sys.modules["botocore.exceptions"] = botocore_exceptions


@pytest.fixture
def reload_module(monkeypatch):
    def _loader(module_path):
        monkeypatch.setenv("DYNAMO_TABLE", "AccountsTable")
        module = importlib.import_module(module_path)
        return importlib.reload(module)

    return _loader


def test_bootstrap_lambda_updates_accounts(monkeypatch, reload_module):
    module = reload_module("lambda_src.accounts.bootstrap_accounts")

    class FakePaginator:
        def __init__(self, pages):
            self.pages = pages

        def paginate(self):
            for page in self.pages:
                yield page

    class FakeOrg:
        def __init__(self, accounts):
            self.accounts = accounts

        def get_paginator(self, name):
            assert name == "list_accounts"
            return FakePaginator([{"Accounts": self.accounts}])

    class FakeTable:
        def __init__(self):
            self.calls = []

        def update_item(self, **kwargs):
            self.calls.append(kwargs)
            return {}

    fake_accounts = [
        {
            "Id": "123456789012",
            "Name": "DevAccount",
            "Email": "DEV@EXAMPLE.COM",
            "Status": "ACTIVE",
            "JoinedTimestamp": datetime(2024, 1, 1, tzinfo=timezone.utc),
        }
    ]

    monkeypatch.setattr(module, "ORG", FakeOrg(fake_accounts))
    fake_table = FakeTable()
    monkeypatch.setattr(module, "TABLE", fake_table)
    monkeypatch.setattr(module, "_get_ou_path", lambda _account_id: "Root/Engineering")
    monkeypatch.setattr(
        module, "_fetch_tags", lambda _account_id: [{"Key": "owner", "Value": "team"}]
    )

    result = module.lambda_handler({}, None)

    assert result == {"inserted": 1, "failed": 0}
    assert len(fake_table.calls) == 1
    assert fake_table.calls[0]["Key"]["AccountEmail"] == "dev@example.com"


def test_update_lambda_marks_account_active(monkeypatch, reload_module):
    module = reload_module("lambda_src.accounts.update_succeed_status")

    updates = []

    def fake_update(_client, table_name, key_field, key_value, update_fields):
        updates.append(
            {
                "table": table_name,
                "key_field": key_field,
                "key_value": key_value,
                "fields": update_fields,
            }
        )
        return {}

    monkeypatch.setattr(module, "get_account_id", lambda *_args: "123456789012")
    monkeypatch.setattr(module, "update_dynamodb_fields_with_timestamp", fake_update)

    event = {"AccountEmail": "owner@example.com", "ProvisionedProductId": "pp-123"}

    response = module.lambda_handler(event.copy(), None)

    assert response["AccountId"] == "123456789012"
    assert response["Status"] == "ACTIVE"
    assert response["Success"] == "True"
    assert len(updates) == 1
    update_call = updates[0]
    assert update_call["table"] == "AccountsTable"
    assert update_call["key_field"] == "AccountEmail"
    assert update_call["key_value"] == "owner@example.com"
    assert update_call["fields"] == {
        "Status": "ACTIVE",
        "AccountId": "123456789012",
    }


def test_update_lambda_handles_missing_account_id(monkeypatch, reload_module):
    module = reload_module("lambda_src.accounts.update_succeed_status")

    updates = []

    def fake_update(_client, table_name, key_field, key_value, update_fields):
        updates.append(
            {
                "table": table_name,
                "key_field": key_field,
                "key_value": key_value,
                "fields": update_fields,
            }
        )
        return {}

    monkeypatch.setattr(module, "get_account_id", lambda *_args: None)
    monkeypatch.setattr(module, "update_dynamodb_fields_with_timestamp", fake_update)

    event = {"AccountEmail": "owner@example.com", "ProvisionedProductId": "pp-123"}

    response = module.lambda_handler(event.copy(), None)

    assert response["Success"] == "False"
    assert "AccountId não encontrado" in response["message"]
    assert len(updates) == 1
    assert updates[0]["fields"] == {"Status": "ERROR", "AccountId": "N/A"}


def test_validate_lambda_returns_normalized_item(monkeypatch, reload_module):
    module = reload_module("lambda_src.accounts.validate_fields")
    monkeypatch.setattr(module, "check_existing_account", lambda *_args: False)
    monkeypatch.setattr(module, "already_processed", lambda *_args: False)

    payload = {
        "AccountName": "DEV-ACCOUNT",
        "AccountEmail": "TEST@EXAMPLE.COM",
        "OrgUnit": "Engineering",
        "SSOUserEmail": "OWNER@EXAMPLE.COM",
        "SSOUserFirstName": "JANE",
        "SSOUserLastName": "DOE",
        "RequestID": "req-1",
    }

    result = module.lambda_handler(payload.copy(), None)

    assert result["Validation"] is True
    assert result["AccountEmail"] == "test@example.com"
    assert result["SSOUserFirstName"] == "Jane"


def test_validate_lambda_raises_on_existing_account(monkeypatch, reload_module):
    module = reload_module("lambda_src.accounts.validate_fields")
    monkeypatch.setattr(module, "check_existing_account", lambda *_args: True)
    monkeypatch.setattr(module, "already_processed", lambda *_args: False)

    payload = {
        "AccountName": "Existing",
        "AccountEmail": "exists@example.com",
        "OrgUnit": "Engineering",
        "SSOUserEmail": "owner@example.com",
        "SSOUserFirstName": "Jane",
        "SSOUserLastName": "Doe",
        "RequestID": "req-1",
    }

    with pytest.raises(Exception) as excinfo:
        module.lambda_handler(payload, None)

    error_payload = json.loads(str(excinfo.value))
    assert error_payload["errorType"] == "ValidationErrorWithData"
    assert error_payload["account_email"] == "exists@example.com"


def test_update_failed_lambda_deletes_item(monkeypatch, reload_module):
    module = reload_module("lambda_src.accounts.update_failed_status")

    class FakeDyn:
        def __init__(self):
            self.deleted = []

        def delete_item(self, **kwargs):
            self.deleted.append(kwargs)
            return {}

    fake_dyn = FakeDyn()
    monkeypatch.setattr(module, "DYNO", fake_dyn)

    error_payload = {
        "Error": {
            "Cause": json.dumps(
                {
                    "errorMessage": json.dumps(
                        {"account_email": "failed@example.com", "details": "boom"}
                    )
                }
            )
        }
    }

    response = module.lambda_handler(error_payload, None)

    assert fake_dyn.deleted
    assert fake_dyn.deleted[0]["Key"]["AccountEmail"]["S"] == "failed@example.com"
    assert response["account_email"] == "failed@example.com"
    assert response["Status"] == "Resquest_removed"
