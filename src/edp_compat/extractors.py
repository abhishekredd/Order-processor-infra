"""EXTRACT: read the referenced file and return the individual business records."""
import json
from pathlib import Path
from typing import Protocol

from .errors import ExtractError, ObjectNotFound
from .models import SourceRef


class BlobReader(Protocol):
    def read_bytes(self, ref: SourceRef) -> bytes: ...


class GcsBlobReader:
    def __init__(self, client=None):
        self._client = client

    def read_bytes(self, ref: SourceRef) -> bytes:
        from google.api_core.exceptions import NotFound
        from google.cloud import storage

        client = self._client or storage.Client()
        try:
            return client.bucket(ref.bucket).blob(ref.name).download_as_bytes()
        except NotFound as exc:
            raise ObjectNotFound(ref.uri) from exc


class LocalBlobReader:
    """Maps gs://bucket/name to <root>/bucket/name. For local runs and tests."""

    def __init__(self, root):
        self.root = Path(root)

    def read_bytes(self, ref: SourceRef) -> bytes:
        path = self.root / ref.bucket / ref.name
        if not path.is_file():
            raise ObjectNotFound(ref.uri)
        return path.read_bytes()


class GcsJsonExtractor:
    """Accepts a single JSON object, a JSON array, or newline-delimited JSON."""

    def __init__(self, reader: BlobReader):
        self.reader = reader

    def extract(self, ref: SourceRef) -> list:
        raw = self.reader.read_bytes(ref)
        try:
            doc = json.loads(raw)
        except json.JSONDecodeError:
            doc = self._try_ndjson(raw, ref)
        return doc if isinstance(doc, list) else [doc]

    @staticmethod
    def _try_ndjson(raw: bytes, ref: SourceRef) -> list:
        try:
            lines = [ln for ln in raw.decode("utf-8").splitlines() if ln.strip()]
            records = [json.loads(ln) for ln in lines]
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ExtractError(f"{ref.uri} is not valid JSON: {exc}") from exc
        if not records:
            raise ExtractError(f"{ref.uri} is empty")
        return records
