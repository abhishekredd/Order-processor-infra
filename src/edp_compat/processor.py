"""The orchestrator: Parse -> Route -> Extract -> (Transform -> Validate -> Encode -> Publish) per record."""
import json
import logging
from dataclasses import asdict, dataclass
from datetime import datetime, timezone

from .encoding import to_pubsub_message
from .errors import CompatError, ExtractError, TransformError, ValidationFailed
from .models import SourceRef

log = logging.getLogger("compat")


@dataclass
class RunSummary:
    source_uri: str = ""
    status: str = "processed"  # processed | skipped
    total: int = 0
    published: int = 0
    dead_lettered: int = 0

    def to_dict(self):
        return asdict(self)


class CompatibilityProcessor:
    def __init__(self, parser, router, extractor, publisher, output_topic: str, dlq_topic: str):
        self.parser, self.router, self.extractor = parser, router, extractor
        self.publisher, self.output_topic, self.dlq_topic = publisher, output_topic, dlq_topic

    def handle(self, headers: dict, body) -> RunSummary:
        ref = self.parser.parse(headers, body)                       # PARSE
        spec = self.router.resolve(ref)                              # ROUTE
        summary = RunSummary(source_uri=ref.uri)
        if spec is None:
            log.info("No route for %s, skipping", ref.uri)
            summary.status = "skipped"
            return summary

        try:
            records = self.extractor.extract(ref)                    # EXTRACT
        except ExtractError as exc:                                  # whole file unreadable
            self._dead_letter(ref, None, None, exc)
            summary.total, summary.dead_lettered = 1, 1
            return summary

        for index, record in enumerate(records):
            summary.total += 1
            try:
                event = spec.process(record)                         # TRANSFORM, VALIDATE, ENCODE
            except (TransformError, ValidationFailed) as exc:        # bad record: DLQ, keep going
                self._dead_letter(ref, index, record, exc)
                summary.dead_lettered += 1
                continue
            data, attrs = to_pubsub_message(event)
            self.publisher.publish(self.output_topic, data, attrs)   # PUBLISH (errors propagate -> retry)
            summary.published += 1

        log.info("Processed %s: %s", ref.uri, summary.to_dict())
        return summary

    def _dead_letter(self, ref: SourceRef, index, record, exc: CompatError) -> None:
        body = {
            "stage": exc.stage,
            "error": str(exc),
            "errors": getattr(exc, "errors", [str(exc)]),
            "source_uri": ref.uri,
            "record_index": index,
            "original_record": record,
            "failed_at": datetime.now(timezone.utc).isoformat(),
        }
        attrs = {"dlq-stage": exc.stage, "dlq-source-uri": ref.uri}
        self.publisher.publish(self.dlq_topic, json.dumps(body, default=str).encode(), attrs)
        log.warning("Dead-lettered record %s of %s at %s: %s", index, ref.uri, exc.stage, exc)
