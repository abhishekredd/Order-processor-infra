"""PUBLISH: Pub/Sub publisher plus test/local stand-ins."""
import sys
from dataclasses import dataclass, field
from typing import Protocol

from .errors import PublishError


class Publisher(Protocol):
    def publish(self, topic: str, data: bytes, attributes: dict) -> str: ...


class PubSubPublisher:
    def __init__(self, project: str, client=None, timeout: float = 30.0):
        self.project, self._client, self.timeout = project, client, timeout

    def publish(self, topic, data, attributes):
        from google.cloud import pubsub_v1

        self._client = self._client or pubsub_v1.PublisherClient()
        path = topic if topic.startswith("projects/") else self._client.topic_path(self.project, topic)
        try:
            return self._client.publish(path, data, **attributes).result(timeout=self.timeout)
        except Exception as exc:  # noqa: BLE001
            raise PublishError(f"Publish to {path} failed: {exc}") from exc


@dataclass
class InMemoryPublisher:
    messages: dict = field(default_factory=dict)

    def publish(self, topic, data, attributes):
        self.messages.setdefault(topic, []).append((data, dict(attributes)))
        return f"mem-{sum(len(v) for v in self.messages.values())}"


class ConsolePublisher:
    """Local mode: prints what would be published."""

    def publish(self, topic, data, attributes):
        print(f"[PUBLISH -> {topic}] {data.decode()}", file=sys.stdout)
        return "console"
