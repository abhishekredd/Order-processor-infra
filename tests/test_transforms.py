import pytest

from edp_compat.errors import TransformError
from edp_compat.transforms import CastFloat, IsoToEpochMillis, Rename, SnakeCaseKeys, to_snake
from retailhub_order.definition import build_transforms

SOURCE = {
    "OrderId": "ORD-1001", "CustomerId": "CUS-900", "OrderDate": "2026-09-25T10:30:00Z",
    "TotalAmount": "1499.50", "OrderStatus": "CONFIRMED", "InternalReference": "RH-ABC-123",
}
EXPECTED = {
    "order_id": "ORD-1001", "customer_id": "CUS-900", "order_date": 1790332200000,
    "total_amount": 1499.50, "status": "CONFIRMED",
}


def test_full_pipeline_matches_expected_output():
    assert build_transforms().apply(SOURCE) == EXPECTED


def test_internal_reference_is_dropped_and_input_not_mutated():
    original = dict(SOURCE)
    out = build_transforms().apply(SOURCE)
    assert "internal_reference" not in out and "InternalReference" not in out
    assert SOURCE == original


def test_types_are_converted():
    out = build_transforms().apply(SOURCE)
    assert isinstance(out["total_amount"], float) and isinstance(out["order_date"], int)


@pytest.mark.parametrize("raw,expected", [("OrderId", "order_id"), ("TotalAmount", "total_amount"),
                                          ("customerURL", "customer_url"), ("already_snake", "already_snake")])
def test_snake(raw, expected):
    assert to_snake(raw) == expected


def test_timestamp_offset_is_respected():
    assert IsoToEpochMillis("t").apply({"t": "2026-09-25T16:00:00+05:30"})["t"] == 1790332200000


def test_naive_timestamp_assumed_utc():
    assert IsoToEpochMillis("t").apply({"t": "2026-09-25T10:30:00"})["t"] == 1790332200000


def test_milliseconds_preserved():
    assert IsoToEpochMillis("t").apply({"t": "2026-09-25T10:30:00.123Z"})["t"] == 1790332200123


@pytest.mark.parametrize("bad", ["abc", "", "NaN", "inf", True])
def test_bad_amount_raises(bad):
    with pytest.raises(TransformError):
        CastFloat("a").apply({"a": bad})


def test_bad_timestamp_raises():
    with pytest.raises(TransformError):
        IsoToEpochMillis("t").apply({"t": "yesterday"})


def test_missing_fields_are_left_for_the_validator():
    assert build_transforms().apply({"OrderId": "X"}) == {"order_id": "X"}


def test_collision_detected():
    with pytest.raises(TransformError):
        SnakeCaseKeys().apply({"OrderId": 1, "order_id": 2})


def test_rename_target_exists():
    with pytest.raises(TransformError):
        Rename({"a": "b"}).apply({"a": 1, "b": 2})


def test_non_object_record_rejected():
    with pytest.raises(TransformError):
        build_transforms().apply("not an object")
