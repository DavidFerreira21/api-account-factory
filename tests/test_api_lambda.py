import json
import sys
import types
from copy import deepcopy
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


class _DummyDynamoResource:
    def Table(self, name):
        return None


class _DummyClient:
    pass


dummy_boto3 = types.ModuleType("boto3")
dummy_boto3.resource = lambda *_args, **_kwargs: _DummyDynamoResource()
dummy_boto3.client = lambda *_args, **_kwargs: _DummyClient()

sys.modules.setdefault("boto3", dummy_boto3)


class _DummyAttr:
    def __init__(self, name):
        self.name = name

    def eq(self, value):
        return (self.name, value)


conditions_module = types.ModuleType("boto3.dynamodb.conditions")
conditions_module.Attr = _DummyAttr
dynamodb_module = types.ModuleType("boto3.dynamodb")
dynamodb_module.conditions = conditions_module
sys.modules.setdefault("boto3.dynamodb", dynamodb_module)
sys.modules.setdefault("boto3.dynamodb.conditions", conditions_module)

botocore_exceptions = types.SimpleNamespace(ClientError=Exception)
sys.modules.setdefault(
    "botocore", types.SimpleNamespace(exceptions=botocore_exceptions)
)
sys.modules.setdefault("botocore.exceptions", botocore_exceptions)

import lambda_src.api.lambda_function as api  # noqa: E402


class StubTable:
    def __init__(self):
        self.items = {}
        self.last_put = None

    def seed(self, item):
        self.items[item["AccountEmail"]] = deepcopy(item)

    def get_item(self, Key):
        email = Key["AccountEmail"]
        item = self.items.get(email)
        return {"Item": deepcopy(item)} if item else {}

    def scan(self, *args, **kwargs):  # pragma: no cover - not exercised directly
        return {"Items": list(self.items.values())}

    def put_item(self, Item, **kwargs):
        email = Item["AccountEmail"]
        if email in self.items:
            raise Exception("ConditionalCheckFailedException")
        self.items[email] = deepcopy(Item)
        self.last_put = deepcopy(Item)
        return {}


@pytest.fixture(autouse=True)
def stub_table(monkeypatch):
    table = StubTable()
    monkeypatch.setattr(api, "table", table)
    return table


def test_get_account_by_email_returns_item(stub_table):
    stored_item = {"AccountEmail": "user@example.com", "AccountName": "dev-account"}
    stub_table.seed(stored_item)

    event = {
        "httpMethod": "GET",
        "queryStringParameters": {"accountEmail": "User@example.com"},
    }

    response = api.lambda_handler(event, None)
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["AccountEmail"] == "user@example.com"
    assert body["AccountName"] == "dev-account"


def test_get_account_without_parameters_returns_400():
    event = {"httpMethod": "GET", "queryStringParameters": None}
    response = api.lambda_handler(event, None)
    assert response["statusCode"] == 400
    assert "Provide accountEmail or accountId" in response["body"]


def test_post_missing_required_field_returns_400():
    payload = {
        "AccountEmail": "new@example.com",
        "AccountName": "new-account",
        # OrgUnit omitted
        "SSOUserEmail": "owner@example.com",
        "SSOUserFirstName": "Jane",
        "SSOUserLastName": "Doe",
    }
    event = {"httpMethod": "POST", "body": json.dumps(payload)}

    response = api.lambda_handler(event, None)
    assert response["statusCode"] == 400
    assert "Missing fields" in response["body"]


def test_post_success_persists_item(monkeypatch, stub_table):
    payload = {
        "AccountEmail": "new@example.com",
        "AccountName": "new-account",
        "OrgUnit": "Engineering",
        "SSOUserEmail": "owner@example.com",
        "SSOUserFirstName": "Jane",
        "SSOUserLastName": "Doe",
        "Tags": [{"Key": "env", "Value": "dev"}],
    }

    monkeypatch.setattr(api, "validate_account_name", lambda _: True)
    monkeypatch.setattr(api, "validate_org_unit", lambda _: True)

    event = {"httpMethod": "POST", "body": json.dumps(payload)}
    response = api.lambda_handler(event, None)

    assert response["statusCode"] == 201
    body = json.loads(response["body"])
    assert body["AccountEmail"] == "new@example.com"
    assert stub_table.last_put is not None
    assert stub_table.last_put["Status"] == "Requested"
    assert stub_table.last_put["Tags"] == payload["Tags"]
