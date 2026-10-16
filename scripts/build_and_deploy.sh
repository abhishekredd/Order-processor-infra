#!/usr/bin/env bash
# Build the image, push it to the Terraform-created Artifact Registry, deploy a new Cloud Run revision.
# Run from the repo root:  ./scripts/build_and_deploy.sh
set -euo pipefail
TF="${TF:-terraform}"
out() { "$TF" -chdir=infra/workload output -raw "$1"; }

PROJECT_ID="$(out project_id)"; REGION="$(out region)"
REPO_URL="$(out image_repository)"; SERVICE="$(out service_name)"
TAG="$(git rev-parse --short HEAD 2>/dev/null || date +%s)"
IMAGE="${REPO_URL}/${SERVICE}:${TAG}"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
docker build --platform linux/amd64 -t "${IMAGE}" .   # linux/amd64: Cloud Run's architecture (matters on Apple Silicon)
docker push "${IMAGE}"
gcloud run deploy "${SERVICE}" --image "${IMAGE}" --region "${REGION}" --project "${PROJECT_ID}"
echo "Deployed ${IMAGE}"
