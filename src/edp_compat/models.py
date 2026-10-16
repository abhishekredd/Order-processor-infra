from dataclasses import dataclass


@dataclass(frozen=True)
class SourceRef:
    """Pointer to the file that triggered processing."""
    bucket: str
    name: str

    @property
    def uri(self) -> str:
        return f"gs://{self.bucket}/{self.name}"
