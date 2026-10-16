"""End-to-end through the HTTP layer with local storage and an in-memory Pub/Sub."""
import base64
import json
import shutil
from pathlib import Path

import pytest

from edp_compat.publishing import InMemoryPublisher
from retailhub_order.app import create_app
from retailhub_order.config import Config
from retailhub_order.factory import build_processor

ROOT = Path(__file__).resolve().parent.parent
BUCKET, OUT, DLQ = "retailhub-input", "order-out", "order-dlq"


@pytest.fixture
def env(tmp_path):
    (tmp_path / BUCKET).mkdir()
    for f in (ROOT / "tests" / "payloads").glob("*.json"):
        shutil.copy(f, tmp_path / BUCKET / f.name)
    (tmp_path / BUCKET / "broken.json").write_text("{not json")
    (tmp_path / BUCKET / "notes.txt").write_text("ignore me")
    pub = InMemoryPublisher()
    cfg = Config(output_topic=OUT, dlq_topic=DLQ, registry_dir=str(ROOT / "contracts"),
                 run_mode="local", local_data_dir=str(tmp_path))
    client = create_app(build_processor(cfg, publisher=pub)).test_client()
    return client, pub


def send(client, name, bucket=BUCKET):
    data = base64.b64encode(json.dumps({"bucket": bucket, "name": name}).encode()).decode()
    return client.post("/", json={"message": {"data": data, "messageId": "m1"}})


def out(pub, topic):
    return [(json.loads(d), a) for d, a in pub.messages.get(topic, [])]


def test_valid_order_is_published_as_cloudevent(env):
    client, pub = env
    resp = send(client, "valid_order.json")
    assert resp.status_code == 200 and resp.json["published"] == 1 and resp.json["dead_lettered"] == 0
    (event, attrs), = out(pub, OUT)
    assert event["data"] == {"order_id": "ORD-1001", "customer_id": "CUS-900", "order_date": 1790332200000,
                             "total_amount": 1499.5, "status": "CONFIRMED"}
    assert "InternalReference" not in event["data"] and "internal_reference" not in event["data"]
    assert event["type"] == "com.rituals.retailhub.order.updated.v1"
    assert event["subject"] == "ORD-1001" and event["specversion"] == "1.0"
    assert event["dataschema"] == "urn:edp:contract:order:1.0.0"
    assert attrs["ce-type"] == event["type"]
    assert out(pub, DLQ) == []


def test_invalid_order_goes_to_dlq_not_output(env):
    client, pub = env
    resp = send(client, "invalid_order.json")
    assert resp.status_code == 200 and resp.json["dead_lettered"] == 1 and resp.json["published"] == 0
    assert out(pub, OUT) == []
    (dlq, attrs), = out(pub, DLQ)
    assert dlq["stage"] == "validate" and attrs["dlq-stage"] == "validate"
    assert dlq["original_record"]["OrderId"] == "ORD-1002"
    for field in ("customer_id", "order_date", "total_amount"):
        assert any(field in e for e in dlq["errors"])


def test_one_bad_record_does_not_stop_the_rest(env):
    client, pub = env
    resp = send(client, "mixed_batch.json")
    assert resp.json == {"source_uri": f"gs://{BUCKET}/mixed_batch.json", "status": "processed",
                         "total": 4, "published": 2, "dead_lettered": 2}
    ok = [e["subject"] for e, _ in out(pub, OUT)]
    assert ok == ["ORD-2001", "ORD-2004"]
    stages = {d["original_record"]["OrderId"]: d["stage"] for d, _ in out(pub, DLQ)}
    assert stages == {"ORD-2002": "validate", "ORD-2003": "transform"}
    assert out(pub, OUT)[1][0]["data"]["order_date"] == 1790389800000  # +05:30 offset handled


def test_unreadable_file_is_dead_lettered(env):
    client, pub = env
    resp = send(client, "broken.json")
    assert resp.status_code == 200 and resp.json["dead_lettered"] == 1
    assert out(pub, DLQ)[0][0]["stage"] == "extract" and out(pub, OUT) == []


def test_unrouted_file_is_skipped(env):
    client, pub = env
    resp = send(client, "notes.txt")
    assert resp.status_code == 200 and resp.json["status"] == "skipped" and pub.messages == {}


def test_missing_file_returns_500_so_it_is_retried(env):
    client, _ = env
    assert send(client, "nope.json").status_code == 500


def test_malformed_request_returns_400(env):
    client, _ = env
    assert client.post("/", json={"hello": "world"}).status_code == 400
    assert client.post("/", data="garbage", content_type="text/plain").status_code == 400


def test_health(env):
    assert env[0].get("/healthz").json == {"status": "ok"}
