"""PARSE: understand the incoming HTTP request and find the file it points to."""
import base64
import json

from .errors import ParseError
from .models import SourceRef


class EventArcPubSubRequestParser:
    """Understands the request EventArc / Pub/Sub sends to Cloud Run.

    Supported shapes:
      1. Pub/Sub push envelope: {"message": {"data": base64(json), "attributes": {...}}}
         where the decoded data holds the GCS object metadata (bucket, name).
      2. Native EventArc CloudEvent, binary mode (body = GCS object JSON, ce-* headers).
      3. Native EventArc CloudEvent, structured mode ({"specversion":..., "data": {...}}).
    """

    def parse(self, headers: dict, body) -> SourceRef:
        if not isinstance(body, dict):
            raise ParseError("Request body is not a JSON object")

        payload, attributes = None, {}
        if isinstance(body.get("message"), dict):
            message = body["message"]
            attributes = message.get("attributes") or {}
            payload = self._decode_data(message.get("data"))
        elif "specversion" in body:
            payload = body.get("data")
        else:
            payload = body

        payload = payload if isinstance(payload, dict) else {}
        bucket = payload.get("bucket") or attributes.get("bucketId")
        name = payload.get("name") or attributes.get("objectId")
        if not bucket or not name:
            raise ParseError("Could not find bucket/object name in the event")
        return SourceRef(bucket=str(bucket), name=str(name))

    @staticmethod
    def _decode_data(data):
        if not data:
            return {}
        try:
            return json.loads(base64.b64decode(data))
        except Exception as exc:  # noqa: BLE001
            raise ParseError(f"Pub/Sub message.data is not base64 JSON: {exc}") from exc
