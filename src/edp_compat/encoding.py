"""ENCODE: wrap a valid record in a CloudEvent and serialise it for Pub/Sub."""
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from .contracts import Contract


@dataclass
class CloudEvent:
    id: str
    source: str
    type: str
    subject: str
    time: str
    dataschema: str
    data: dict
    specversion: str = "1.0"
    datacontenttype: str = "application/json"

    def to_dict(self) -> dict:
        return dict(self.__dict__)


class CloudEventEncoder:
    def __init__(self, contract: Contract, contract_major: int):
        self.contract, self.major = contract, contract_major

    def encode(self, record: dict) -> CloudEvent:
        c = self.contract
        return CloudEvent(
            id=str(uuid.uuid4()),
            source=f"/{c.source}/{c.model}",
            type=c.event_type(self.major),
            subject=str(record[c.subject_key]),
            time=datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
            dataschema=c.urn,
            data=record,
        )


def to_pubsub_message(event: CloudEvent) -> tuple:
    """Structured-mode CloudEvent: full envelope in the body, key fields mirrored as attributes."""
    body = json.dumps(event.to_dict(), separators=(",", ":")).encode("utf-8")
    attrs = {
        "ce-specversion": event.specversion,
        "ce-id": event.id,
        "ce-type": event.type,
        "ce-source": event.source,
        "ce-subject": event.subject,
    }
    return body, attrs
