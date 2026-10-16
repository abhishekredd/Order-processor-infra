import base64
import json

import pytest

from edp_compat.errors import ParseError
from edp_compat.parsers import EventArcPubSubRequestParser

P = EventArcPubSubRequestParser()


def envelope(payload):
    return {"message": {"data": base64.b64encode(json.dumps(payload).encode()).decode(), "messageId": "1"}}


def test_pubsub_envelope():
    ref = P.parse({}, envelope({"bucket": "b", "name": "o/x.json"}))
    assert (ref.bucket, ref.name, ref.uri) == ("b", "o/x.json", "gs://b/o/x.json")


def test_pubsub_attributes_fallback():
    ref = P.parse({}, {"message": {"attributes": {"bucketId": "b", "objectId": "x.json"}}})
    assert ref.uri == "gs://b/x.json"


def test_native_binary_cloudevent():
    assert P.parse({"ce-type": "google.cloud.storage.object.v1.finalized"}, {"bucket": "b", "name": "x.json"}).uri == "gs://b/x.json"


def test_native_structured_cloudevent():
    assert P.parse({}, {"specversion": "1.0", "data": {"bucket": "b", "name": "x.json"}}).uri == "gs://b/x.json"


@pytest.mark.parametrize("body", [None, [], "x", {}, {"message": {"data": "!!notbase64!!"}}, envelope({"bucket": "b"})])
def test_bad_requests(body):
    with pytest.raises(ParseError):
        P.parse({}, body)
