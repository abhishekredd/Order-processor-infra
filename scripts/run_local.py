"""Run the processor locally against a file in sample_data/, no GCP needed.

    python scripts/run_local.py valid_order.json
    python scripts/run_local.py invalid_order.json
    python scripts/run_local.py mixed_batch.json
"""
import base64
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))

from retailhub_order.config import Config  # noqa: E402
from retailhub_order.factory import build_processor  # noqa: E402

name = sys.argv[1] if len(sys.argv) > 1 else "valid_order.json"
cfg = Config(run_mode="local", local_data_dir=str(ROOT / "sample_data"), registry_dir=str(ROOT / "contracts"))
envelope = {"message": {"data": base64.b64encode(json.dumps({"bucket": "local-bucket", "name": name}).encode()).decode()}}
summary = build_processor(cfg).handle({}, envelope)
print("\nSUMMARY:", json.dumps(summary.to_dict()))
print(f"(output topic = {cfg.output_topic}, DLQ topic = {cfg.dlq_topic})")
