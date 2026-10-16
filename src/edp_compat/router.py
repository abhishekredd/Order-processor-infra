"""ROUTE: decide which contract/pipeline handles a given file."""
import fnmatch
from dataclasses import dataclass

from .contracts import Contract
from .encoding import CloudEvent, CloudEventEncoder
from .models import SourceRef
from .transforms import TransformPipeline
from .validation import ContractValidator


@dataclass
class ProcessorSpec:
    """Everything needed to turn one source record into one contract-valid CloudEvent."""
    contract: Contract
    transforms: TransformPipeline
    validator: ContractValidator
    encoder: CloudEventEncoder

    def process(self, record) -> CloudEvent:
        transformed = self.transforms.apply(record)
        self.validator.validate(transformed)
        return self.encoder.encode(transformed)


@dataclass
class Route:
    pattern: str  # glob on the object name, e.g. "*.json"
    spec: ProcessorSpec


class Router:
    def __init__(self, routes):
        self.routes = list(routes)

    def resolve(self, ref: SourceRef):
        for route in self.routes:
            if fnmatch.fnmatch(ref.name, route.pattern):
                return route.spec
        return None
