"""VALIDATE: check the transformed record against the contract's JSON Schema."""
from jsonschema import Draft202012Validator

from .errors import ValidationFailed


class ContractValidator:
    def __init__(self, schema: dict):
        Draft202012Validator.check_schema(schema)
        self._validator = Draft202012Validator(schema)

    def validate(self, record: dict) -> None:
        errors = sorted(self._validator.iter_errors(record), key=lambda e: list(e.absolute_path))
        if errors:
            raise ValidationFailed(
                (f"{'.'.join(map(str, e.absolute_path))}: " if e.absolute_path else "") + e.message
                for e in errors
            )
