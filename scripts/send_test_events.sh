#!/usr/bin/env bash
# Upload the valid + invalid payloads, then read both verification subscriptions.
# Run from the repo root:  ./scripts/send_test_events.sh
set -euo pipefail
TF="${TF:-terraform}"
out() { "$TF" -chdir=infra/workload output -raw "$1"; }

PROJECT_ID="$(out project_id)"; BUCKET="$(out input_bucket)"
OUT_SUB="$(out output_verify_subscription)"; DLQ_SUB="$(out dlq_verify_subscription)"
TS="$(date +%s)"

gcloud storage cp tests/payloads/valid_order.json   "gs://${BUCKET}/valid_${TS}.json"
gcloud storage cp tests/payloads/invalid_order.json "gs://${BUCKET}/invalid_${TS}.json"
echo "Waiting 20s for EventArc + processing..."; sleep 20

echo "=== OUTPUT topic (expect 1 CloudEvent for ORD-1001) ==="
gcloud pubsub subscriptions pull "${OUT_SUB}" --auto-ack --limit=5 --project "${PROJECT_ID}"
echo "=== DLQ topic (expect 1 record for ORD-1002) ==="
gcloud pubsub subscriptions pull "${DLQ_SUB}" --auto-ack --limit=5 --project "${PROJECT_ID}"
