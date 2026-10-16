# retailhub-order-compat-processor

Turns RetailHub order files (GCS) into contract-compliant Order CloudEvents on Pub/Sub.
Invalid records go to a DLQ topic; they never block the rest of the file.

    GCS -> EventArc -> Cloud Run (this service) -> Pub/Sub output topic
                                                \-> Pub/Sub DLQ topic

Pipeline: Parse -> Route -> Extract -> Transform -> Validate -> Encode -> Publish

## Layout
| Path | Purpose |
|---|---|
| `src/edp_compat/` | Reusable mini-framework: parser, router, extractor, transforms, validator, encoder, publisher |
| `src/retailhub_order/definition.py` | **RetailHub-specific**: the contract identity + ordered transform pipeline |
| `src/retailhub_order/config.py` | Env-driven config (project, topics, registry, URN) |
| `contracts/order.v1.json` | Demo stand-in for the Data Contract Registry entry |
| `tests/` | Unit + integration tests (valid, invalid, mixed batch, failure modes) |
| `scripts/run_local.py` | Run locally with no GCP |
| `infra/` | Terraform: bootstrap, foundation (project + CI identities), workload (the processor), reusable modules |
| `scripts/` | local runner, manual build+deploy fallback, end-to-end test |

## Run locally
    pip install -r requirements-dev.txt
    python -m pytest -v
    python scripts/run_local.py valid_order.json     # -> CloudEvent on output topic
    python scripts/run_local.py invalid_order.json   # -> DLQ record

## Docker (local)
    docker build -t retailhub-order-compat-processor .
    docker run --rm -p 8080:8080 -e RUN_MODE=local -e LOCAL_DATA_DIR=/data \
      -e CONTRACT_REGISTRY_DIR=/app/contracts -v $PWD/sample_data:/data retailhub-order-compat-processor

## Deploy to GCP (Terraform + GitHub Actions)
All infrastructure, including the GCP project, is code in `infra/`; delivery runs through GitHub Actions with keyless auth.

| Doc | Content |
|---|---|
| [infra/README.md](infra/README.md) | Architecture, setup steps, state management, destroy |
| [docs/IAM.md](docs/IAM.md) | Every IAM binding and why it exists |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Troubleshooting and recovery |
| [docs/CHANGE_DEMO.md](docs/CHANGE_DEMO.md) | Demonstrating a controlled change |

After the infrastructure exists: `./scripts/send_test_events.sh` proves the output topic and dead-letter topic.

## Config (env vars)
`GCP_PROJECT`, `OUTPUT_TOPIC`, `DLQ_TOPIC`, `CONTRACT_URN`, `CONTRACT_REGISTRY_DIR` or `CONTRACT_REGISTRY_URL`,
`INPUT_PATTERN` (default `*.json`), `RUN_MODE` (`gcp`|`local`), `LOCAL_DATA_DIR`.

## HTTP behaviour
| Situation | Response | Why |
|---|---|---|
| Records processed (even if some dead-lettered) | 200 | Handled, nothing lost |
| File is not a routed type (e.g. `.txt`) | 200 skipped | Not ours |
| Malformed request | 400 | Retrying can't help |
| File missing / Pub/Sub failure | 500 | Transient, let EventArc retry |
| File is not valid JSON | 200 + DLQ | Permanent, retrying can't help |
