# Demonstrating a controlled change (Task 5)

Goal: change one Cloud Run setting through the intended workflow, show the plan before applying, confirm the
deployed value matches Terraform, then prove a second plan is clean.

Example change: **memory 512Mi to 1Gi** (CPU, concurrency and instance counts work the same way).

```powershell
$P = "retailhub-compat-dev-xxxx"; $R = "asia-south1"; $S = "retailhub-order-compat-processor"
```

## 0. Baseline
```powershell
gcloud run services describe $S --region $R --project $P --format="value(spec.template.spec.containers[0].resources.limits.memory)"
```
Expect `512Mi`. Keep a screenshot.

## 1. Make the change in a branch
```powershell
git checkout -b change/cloud-run-memory
```
Edit `infra/workload/environments/dev.tfvars`:
```hcl
memory = "1Gi"     # was "512Mi"
```
```powershell
git add infra/workload/environments/dev.tfvars
git commit -m "Increase Cloud Run memory to 1Gi"
git push -u origin change/cloud-run-memory
```
Open a pull request.

## 2. Show the plan BEFORE applying
On the pull request, the `terraform` workflow runs the static checks, then the read-only plan, and posts it as a comment.
Expect one change only, on the Cloud Run service, shaped like:
```
~ resources { limits = { memory = "512Mi" -> "1Gi" } }
Plan: 0 to add, 1 to change, 0 to destroy.
```
Point out: **nothing has been applied**. A pull request cannot apply; it only has the read-only identity.

## 3. Apply through the intended workflow
Merge the pull request. On `main` the workflow plans again and the `apply` job pauses at **"Waiting for review"**
(environment `dev`). Approve it. It applies *the saved plan* from the previous step, under the apply identity, with state locking.

## 4. Confirm the deployment matches the code
```powershell
gcloud run services describe $S --region $R --project $P --format="value(spec.template.spec.containers[0].resources.limits.memory)"
```
Expect `1Gi`, which equals `memory` in `dev.tfvars`. Compare the other settings the same way:
```powershell
gcloud run services describe $S --region $R --project $P --format=yaml
```
and read `containerConcurrency`, `resources.limits` and the `autoscaling.knative.dev/minScale|maxScale` annotations against `dev.tfvars`.

## 5. Prove no further changes are needed
The `apply` job already ends with a second plan and fails the pipeline if it is not empty; its last log line should read
`No further changes required.` Show it, and also run it by hand:
```powershell
cd infra/workload
terraform init -backend-config="backend.hcl"
terraform plan -var-file="environments/dev.tfvars" -var="project_id=$P" -detailed-exitcode
echo $LASTEXITCODE
```
Expect `No changes. Your infrastructure matches the configuration.` and exit code `0`.

## What to capture as evidence
1. Baseline value (512Mi).
2. The plan comment on the pull request.
3. The `apply` job waiting for approval, then succeeding.
4. The new value (1Gi) from `gcloud`.
5. The clean second plan (pipeline log and local run).

## Rollback
Revert the commit (a new pull request), review its plan, merge and approve. The same path runs in reverse.
