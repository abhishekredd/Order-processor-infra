# Infrastructure (Terraform) and delivery pipeline

Reproducible, least-privilege GCP infrastructure for the RetailHub Order Compatibility Processor,
deployed through GitHub Actions with keyless authentication.

## How it is organised: three stacks, two kinds of people

```
infra/
├── bootstrap/   Shared Terraform state bucket (existing admin project). Run once. Never destroyed with an environment.
├── foundation/  The GCP project, API enablement, CI identities, GitHub trust.   Run by a HUMAN, once per environment.
├── workload/    The processor itself (bucket, Cloud Run, Pub/Sub, EventArc, IAM). Planned/applied by the PIPELINE.
├── modules/     Reusable building blocks used by the stacks above.
├── .tflint.hcl  Lint rules          .checkov.yaml  Security-scan config
```

Why split foundation from workload? A pipeline must not hold permission to create projects or
mint its own identities. The foundation creates the project and the *limited* identities the
pipeline then uses; the pipeline can only touch what is inside that project.

```
 you (once)                    GitHub Actions (every change)
 ──────────                    ─────────────────────────────
 bootstrap  -> state bucket
 foundation -> project + APIs + tf-plan / tf-apply / gh-deployer + GitHub trust
                                   │
        PR        ─ static checks ─┴─> plan (read-only identity) ──> comment on the PR
        merge     ─ static checks ───> plan ──> [ approval ] ──> apply the SAME plan (apply identity)
        app code  ─ tests ───────────────────> [ approval ] ──> build, push, deploy to Cloud Run
```

## Assessment map

| Requirement | Where |
|---|---|
| Task 1: bucket, Cloud Run, output topic + subscription, dead-letter topic + policy, EventArc trigger, service accounts + IAM, APIs | `workload/main.tf` + `modules/*`; APIs in `foundation/main.tf` |
| Task 2: variables, outputs, config separate from code | `*/variables.tf`, `*/outputs.tf`, `workload/environments/*.tfvars` |
| Task 2: remote backend + locking, version pins | `backend "gcs"` in `*/versions.tf`; `required_version` + `~> 6.0` provider pins; commit `.terraform.lock.hcl` |
| Task 2: clean repeat plans | `ignore_changes` on the image (owned by CI/CD); see "Idempotency" below |
| Task 3: least-privilege IAM, rationale | `docs/IAM.md` |
| Task 4: pipeline | `.github/workflows/terraform.yml` (infrastructure), `.github/workflows/ci-cd.yml` (application) |
| Task 5: demonstrate a change | `docs/CHANGE_DEMO.md` |
| Task 6: troubleshooting | `docs/RUNBOOK.md` |

## First-time setup

**Prerequisites:** Terraform >= 1.5, `gcloud`, Git. Your identity needs *Project Creator* on the
org/folder and *Billing Account User* on the billing account. Run `gcloud auth login` and
`gcloud auth application-default login`. These two logins are the only manual steps.

**1. Bootstrap: state bucket + the admin project's APIs (once, shared by every environment)**
Everything here is Terraform, including the APIs the admin project needs in order to create and bill a new project.
Only the two logins are manual. Pick a NEW globally unique bucket name (a bucket from an earlier experiment is not reused).
```
cd infra/bootstrap
terraform init
terraform apply -var="admin_project_id=ADMIN_PROJECT" -var="state_bucket_name=NEW-UNIQUE-TFSTATE-NAME"
```
Bootstrap keeps its own state locally (`terraform.tfstate`, git-ignored). Keep that file; it is the only state not stored in the bucket.

**2. Foundation (project + CI identities)**
```
cd ../foundation
cp terraform.tfvars.example terraform.tfvars     # billing account, org, github repo, state bucket
cp backend.hcl.example backend.hcl               # state bucket name
terraform init -backend-config="backend.hcl"
terraform apply -var-file="environments/dev.tfvars"
terraform output github_repository_variables     # copy these into GitHub
```

**3. GitHub settings** (Settings in your repository)
- *Secrets and variables > Actions > Variables*: add everything printed by `github_repository_variables`
  (`GCP_PROJECT_ID`, `GCP_REGION`, `WIF_PROVIDER`, `TF_PLAN_SA`, `TF_APPLY_SA`, `DEPLOYER_SA`, `TF_STATE_BUCKET`).
  They are identifiers, not credentials; no secret is needed anywhere.
- *Environments > New environment* named **`dev`** (must match `github_environment`):
  - add yourself under **Required reviewers**
  - under **Deployment branches**, select **main** only
  
  The apply and deploy identities trust *only* jobs running in this environment, so this is the control point.
  Note: required reviewers on private repositories need a paid GitHub plan; on a free plan use a public repository.
- *Rules*: protect `main` and require pull requests, so nothing reaches `main` unreviewed.

**4. Workload (the processor's infrastructure) via the pipeline**
Merge a change touching `infra/` to `main`. The workflow checks, plans, waits for your approval, then applies.
If the EventArc trigger fails on a brand-new project (IAM propagation), re-run the failed job.

**5. Deploy the application**
Push a change under `src/` (or re-run the `app-ci-cd` workflow). After approval it builds the image, pushes it to
Artifact Registry and deploys a new Cloud Run revision. The first apply creates the service with a placeholder image.

**6. Prove the path works**
```
./scripts/send_test_events.sh
```

## Environment-specific settings
All environment differences live in `environments/<env>.tfvars` (committed, non-secret). `dev.tfvars` is
disposable and cheap; `prod.tfvars` turns on deletion protection, `min_instances = 1`, more memory and retention.
Values that identify *you* (billing account, org, repo) live in `terraform.tfvars`, which is git-ignored.
A new environment = a new tfvars file + a new state `prefix` + a new GitHub Environment. The CI in this repo is wired to `dev`.

## State management
- **Remote backend:** GCS bucket created by `bootstrap`. The GCS backend provides **state locking natively**
  (a lock object next to the state), so concurrent applies fail fast instead of corrupting state.
- **Isolation:** one state prefix per stack and environment: `retailhub-order-compat/foundation/dev`, `.../workload/dev`.
- **Safety:** bucket versioning is on (any state revision can be restored), public access is prevented, and the
  bucket has `prevent_destroy`. It lives in the admin project, so destroying an environment never touches it.
- **Plans use `-lock=false`:** the plan identity can only read state. A plan never writes state, so no lock is needed.
  Apply always takes the lock.
- **No secrets in state:** nothing here handles credentials; there are no keys and no sensitive variables.

## Idempotency: why a second plan is empty
- Image: Cloud Run's container image is in `lifecycle.ignore_changes`; CI/CD ships new images with `gcloud run deploy`
  and Terraform must not roll them back. The same applies to the `client` and `client_version` fields gcloud stamps.
- Names are deterministic; no `timestamp()` or random values exist in the workload stack.
- The `apply` job ends with a second `terraform plan -detailed-exitcode` and **fails the pipeline if it exits 2**.

## Destroying an environment safely
```
# 1. the workload (processor + data plane); needs the apply identity or your own admin rights
cd infra/workload
terraform init -backend-config="backend.hcl"
terraform destroy -var-file="environments/dev.tfvars" -var="project_id=PROJECT_ID"

# 2. the foundation (deletes the project; dev has deletion_policy = DELETE)
cd ../foundation
terraform destroy -var-file="environments/dev.tfvars"
```
The shared state bucket in the admin project is outside both stacks and is untouched. Destroying the foundation
removes the IAM grants it made on that bucket, nothing else. Google keeps a deleted project for 30 days before purging.
`prod` cannot be destroyed by accident: `deletion_policy = PREVENT` and Cloud Run deletion protection.

## What is deliberately not done (hardening for production)
- Customer-managed encryption keys for Pub/Sub, Artifact Registry and buckets (Google-managed keys are used).
- Project-wide Data Access audit logs and bucket access logging (Admin Activity logs, which capture every IAM change, are always on).
- Restricting Cloud Run ingress to internal traffic. It is IAM-protected (only the EventArc identity can invoke it) but has a public URL.
- IAM conditions limiting which roles the apply identity may grant. It holds `projectIamAdmin`, which is inherent to
  Terraform managing project IAM; it is contained by the approval gate and by living in a dedicated project.
- A scheduled drift-detection workflow.
