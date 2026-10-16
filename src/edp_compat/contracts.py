"""CONTRACT: what this processor produces, and where its schema lives."""
import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Contract:
    source: str
    model: str
    subject_key: str
    event_verb: str
    urn: str
    org_prefix: str = "com.rituals"

    def event_type(self, major_version: int) -> str:
        return f"{self.org_prefix}.{self.source}.{self.model}.{self.event_verb}.v{major_version}"


@dataclass(frozen=True)
class RegisteredContract:
    """What the registry returns for a URN."""
    urn: str
    version: str
    schema: dict

    @property
    def major_version(self) -> int:
        return int(self.version.split(".")[0])


class ContractNotFound(Exception):
    pass


class LocalFileContractRegistry:
    """Demo stand-in for the Data Contract Registry: reads *.json files from a folder."""

    def __init__(self, directory):
        self.directory = Path(directory)

    def get(self, urn: str) -> RegisteredContract:
        for path in sorted(self.directory.glob("*.json")):
            doc = json.loads(path.read_text())
            if doc.get("urn") == urn:
                return RegisteredContract(urn=urn, version=doc["version"], schema=doc["schema"])
        raise ContractNotFound(f"No contract with URN {urn} in {self.directory}")


class HttpContractRegistry:
    """Same interface against a remote registry: GET {base_url}/contracts/{urn}."""

    def __init__(self, base_url: str, timeout: float = 10.0):
        self.base_url, self.timeout = base_url.rstrip("/"), timeout

    def get(self, urn: str) -> RegisteredContract:
        import urllib.error
        import urllib.parse
        import urllib.request

        url = f"{self.base_url}/contracts/{urllib.parse.quote(urn, safe='')}"
        try:
            with urllib.request.urlopen(url, timeout=self.timeout) as resp:
                doc = json.load(resp)
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                raise ContractNotFound(urn) from exc
            raise
        return RegisteredContract(urn=urn, version=doc["version"], schema=doc["schema"])
