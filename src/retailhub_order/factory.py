"""Wires the pieces together from config. Dependencies can be injected for tests."""
from edp_compat.contracts import HttpContractRegistry, LocalFileContractRegistry
from edp_compat.encoding import CloudEventEncoder
from edp_compat.extractors import GcsBlobReader, GcsJsonExtractor, LocalBlobReader
from edp_compat.parsers import EventArcPubSubRequestParser
from edp_compat.processor import CompatibilityProcessor
from edp_compat.publishing import ConsolePublisher, PubSubPublisher
from edp_compat.router import ProcessorSpec, Route, Router
from edp_compat.validation import ContractValidator

from .config import Config
from .definition import build_contract, build_transforms


def build_processor(config: Config, registry=None, reader=None, publisher=None) -> CompatibilityProcessor:
    local = config.run_mode == "local"

    registry = registry or (
        HttpContractRegistry(config.registry_url) if config.registry_url
        else LocalFileContractRegistry(config.registry_dir)
    )
    registered = registry.get(config.contract_urn)          # fail fast at startup if the URN is wrong

    contract = build_contract(config.contract_urn)
    spec = ProcessorSpec(
        contract=contract,
        transforms=build_transforms(),
        validator=ContractValidator(registered.schema),
        encoder=CloudEventEncoder(contract, registered.major_version),
    )

    reader = reader or (LocalBlobReader(config.local_data_dir) if local else GcsBlobReader())
    publisher = publisher or (ConsolePublisher() if local else PubSubPublisher(config.project))

    return CompatibilityProcessor(
        parser=EventArcPubSubRequestParser(),
        router=Router([Route(config.input_pattern, spec)]),
        extractor=GcsJsonExtractor(reader),
        publisher=publisher,
        output_topic=config.output_topic,
        dlq_topic=config.dlq_topic,
    )
