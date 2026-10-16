"""TRANSFORM: ordered pipeline that adapts a source record to the contract's shape.

Transforms never mutate their input. Missing fields are left alone on purpose:
absence is the *validator's* job to report (that is what sends ORD-1002 to the DLQ).
"""
import math
import re
from datetime import datetime, timedelta, timezone
from typing import Protocol

from .errors import TransformError

_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


class Transform(Protocol):
    def apply(self, record: dict) -> dict: ...


def to_snake(name: str) -> str:
    s = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    return re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s).lower()


class SnakeCaseKeys:
    """Field-name normalisation: OrderId -> order_id."""

    def apply(self, record):
        out = {}
        for key, value in record.items():
            new = to_snake(key)
            if new in out:
                raise TransformError(f"Field name collision after normalising '{key}' -> '{new}'")
            out[new] = value
        return out


class Rename:
    def __init__(self, mapping: dict):
        self.mapping = mapping

    def apply(self, record):
        out = {}
        for key, value in record.items():
            new = self.mapping.get(key, key)
            if new in out or (new != key and new in record):
                raise TransformError(f"Cannot rename '{key}' to '{new}': target already exists")
            out[new] = value
        return out


class CastFloat:
    """"1499.50" -> 1499.5"""

    def __init__(self, field: str):
        self.field = field

    def apply(self, record):
        if self.field not in record or record[self.field] is None:
            return dict(record)
        value = record[self.field]
        try:
            if isinstance(value, bool):
                raise ValueError("boolean is not a number")
            number = float(value.strip() if isinstance(value, str) else value)
            if not math.isfinite(number):
                raise ValueError("not a finite number")
        except (ValueError, TypeError) as exc:
            raise TransformError(f"Field '{self.field}': cannot convert {value!r} to float ({exc})") from exc
        return {**record, self.field: number}


class IsoToEpochMillis:
    """"2026-09-25T10:30:00Z" -> 1790332200000. Naive timestamps are assumed UTC."""

    def __init__(self, field: str):
        self.field = field

    def apply(self, record):
        if self.field not in record or record[self.field] is None:
            return dict(record)
        value = record[self.field]
        if isinstance(value, bool):
            raise TransformError(f"Field '{self.field}': {value!r} is not a timestamp")
        if isinstance(value, int):  # already epoch millis
            return dict(record)
        try:
            dt = datetime.fromisoformat(str(value).strip())
        except ValueError as exc:
            raise TransformError(f"Field '{self.field}': {value!r} is not an ISO-8601 timestamp") from exc
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        millis = (dt - _EPOCH) // timedelta(milliseconds=1)  # exact integer math, no float drift
        return {**record, self.field: millis}


class Drop:
    def __init__(self, fields):
        self.fields = set(fields)

    def apply(self, record):
        return {k: v for k, v in record.items() if k not in self.fields}


class TransformPipeline:
    def __init__(self, steps):
        self.steps = list(steps)

    def apply(self, record):
        if not isinstance(record, dict):
            raise TransformError(f"Record is not a JSON object (got {type(record).__name__})")
        for step in self.steps:
            record = step.apply(record)
        return record
