import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    project: str = "demo-project"
    output_topic: str = "retailhub-order-events"
    dlq_topic: str = "retailhub-order-events-dlq"
    contract_urn: str = "urn:edp:contract:order:1.0.0"
    registry_dir: str = "contracts"          # demo registry: folder of contract files
    registry_url: str = ""                   # if set, use the HTTP registry instead
    input_pattern: str = "*.json"
    run_mode: str = "gcp"                    # gcp | local
    local_data_dir: str = "sample_data"      # local mode: <dir>/<bucket>/<object>

    @classmethod
    def from_env(cls) -> "Config":
        e = os.environ.get
        d = cls()
        return cls(
            project=e("GCP_PROJECT", d.project),
            output_topic=e("OUTPUT_TOPIC", d.output_topic),
            dlq_topic=e("DLQ_TOPIC", d.dlq_topic),
            contract_urn=e("CONTRACT_URN", d.contract_urn),
            registry_dir=e("CONTRACT_REGISTRY_DIR", d.registry_dir),
            registry_url=e("CONTRACT_REGISTRY_URL", d.registry_url),
            input_pattern=e("INPUT_PATTERN", d.input_pattern),
            run_mode=e("RUN_MODE", d.run_mode),
            local_data_dir=e("LOCAL_DATA_DIR", d.local_data_dir),
        )
