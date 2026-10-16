"""Error types. Each carries the pipeline stage it belongs to (used in DLQ messages)."""


class CompatError(Exception):
    stage = "unknown"


class ParseError(CompatError):
    stage = "parse"


class ExtractError(CompatError):
    """Source content is permanently unreadable (e.g. invalid JSON). Goes to DLQ."""
    stage = "extract"


class ObjectNotFound(CompatError):
    """Source object missing. Treated as transient: request fails so it is retried."""
    stage = "extract"


class TransformError(CompatError):
    stage = "transform"


class ValidationFailed(CompatError):
    stage = "validate"

    def __init__(self, errors):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


class PublishError(CompatError):
    stage = "publish"
