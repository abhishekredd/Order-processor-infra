"""THE PART THAT IS SPECIFIC TO RETAILHUB. Everything else is reusable framework.

Read top to bottom: it is the answer to "what differs between RetailHub and the Order contract?"
"""
from edp_compat.contracts import Contract
from edp_compat.transforms import (
    CastFloat, Drop, IsoToEpochMillis, Rename, SnakeCaseKeys, TransformPipeline,
)


def build_contract(urn: str) -> Contract:
    return Contract(
        source="retailhub",
        model="order",
        subject_key="order_id",
        event_verb="updated",
        urn=urn,
    )


def build_transforms() -> TransformPipeline:
    """Ordered. Order matters: normalise names first, then act on the new names."""
    return TransformPipeline([
        SnakeCaseKeys(),                                  # OrderId -> order_id, TotalAmount -> total_amount ...
        Rename({"order_status": "status"}),               # the one name that isn't a pure case change
        CastFloat("total_amount"),                        # "1499.50" -> 1499.5
        IsoToEpochMillis("order_date"),                   # "2026-09-25T10:30:00Z" -> 1790332200000
        Drop(["internal_reference"]),                     # not in the contract
    ])
