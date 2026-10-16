# Troubleshooting and recovery runbook

Commands are PowerShell; set these once (use your real values):
```powershell
$P = "retailhub-compat-dev-xxxx"                 # project id (terraform output project_id)
$R = "asia-south1"
$S = "retailhub-order-compat-processor"
$B = "$P-retailhub-input"
```
**Golden rule:** fix problems in Terraform (a pull request), not in the console. A console fix works today
and shows up as drift tomorrow. Use the console to *look*, Terraform to *change*.

---

## 1. EventArc trigger does not invoke Cloud Run

Follow the event along its path and find where it stops.

| # | Question | How to check | If "no" |
|---|---|---|---|
| 1 | Is a real, matching object upload happening? | `gcloud storage ls gs://$B` ; bucket and trigger must be in the **same region** | Region mismatch means the trigger never fires; fix `region` and recreate both |
| 2 | Is the trigger healthy and pointed at the right bucket/service? | `gcloud eventarc triggers describe "$S-trigger" --location $R --project $P` (check `matchingCriteria.bucket`, `destination`, `serviceAccount`) | Fix in Terraform |
| 3 | Is Cloud Storage able to publish the event? | `gcloud projects get-iam-policy $P --flatten="bindings[].members" --filter="bindings.members:gs-project-accounts" --format="table(bindings.role)"` should show `roles/pubsub.publisher` | Missing binding in `modules/eventarc` (check `terraform plan`) |
| 4 | Is the event reaching delivery and failing? | Pub/Sub subscriptions with an `eventarc-` name exist (`gcloud pubsub subscriptions list --project $P`); an ever-growing undelivered backlog in Console > Pub/Sub > Metrics means events arrive but the call to Cloud Run fails | Go to step 5 |
| 5 | What does Cloud Run answer? | `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$S AND httpRequest.status>=400" --project $P --limit 10 --freshness 1h` | See below |

Reading the status code:
- **403** : the trigger identity lacks `roles/run.invoker`. `gcloud run services get-iam-policy $S --region $R --project $P`.
- **400** : our parser rejected the request (see app logs for `Unparseable request`).
- **404** : wrong destination path.
- **5xx** : the app failed; EventArc/Pub/Sub will retry. Read the app logs: `gcloud run services logs read $S --region $R --project $P --limit 30`.
- **No request at all** : events are not being published (step 3) or the trigger criteria do not match.
- **200 but nothing in Pub/Sub** : (a) the file name did not match `INPUT_PATTERN` (log says `No route`), or (b) **the placeholder "hello" image is still deployed**.
  Confirm with `gcloud run services describe $S --region $R --project $P --format="value(spec.template.spec.containers[0].image)"`;
  it should point at Artifact Registry, not `cloudrun/container/hello`. Run the app deploy workflow.

*State, dependencies, IAM:* the trigger resource depends on the service and on the GCS-agent binding. A brand-new project
can reject the first trigger because IAM has not propagated yet, so re-running the apply fixes it. `terraform state show
module.eventarc.google_eventarc_trigger.on_upload` shows what Terraform believes exists; `terraform plan` shows whether reality differs.

---

## 2. Permission denied when publishing to Pub/Sub

The error appears in Cloud Run logs as a `PublishError` containing `403`/`PERMISSION_DENIED`. A `404`/`NOT_FOUND` is a different
problem (wrong topic name or project).

1. **Which identity is the service really using?**
   `gcloud run services describe $S --region $R --project $P --format="value(spec.template.spec.serviceAccountName)"`
   It must be `compat-processor@...`. If it is the default compute account, the service has drifted from Terraform.
2. **Does that identity hold the role on the topic?**
   `gcloud pubsub topics get-iam-policy retailhub-order-events --project $P` and the same for `retailhub-order-events-dlq`.
   Expect `roles/pubsub.publisher` for the runtime account on both.
3. **Is the app pointed at the right topic?**
   `gcloud run services describe $S --region $R --project $P --format="yaml(spec.template.spec.containers[0].env)"`; check `GCP_PROJECT`, `OUTPUT_TOPIC`, `DLQ_TOPIC`.
4. **Ask IAM directly:**
   `gcloud policy-troubleshoot iam //pubsub.googleapis.com/projects/$P/topics/retailhub-order-events --principal-email=compat-processor@$P.iam.gserviceaccount.com --permission=pubsub.topics.publish`
5. **Just changed?** New bindings can take a few minutes to propagate. Retry before changing anything.
6. **Dead-letter delivery specifically:** the *Pub/Sub service agent* needs `publisher` on the dead-letter topic and `subscriber`
   on the output subscription (`gcloud pubsub subscriptions get-iam-policy retailhub-order-events-verify --project $P`).

Fix by editing the `publishers` map in `modules/pubsub` / `workload/main.tf` through a pull request.

*State, dependencies, IAM:* the topics, the runtime account and the bindings are separate resources. If a binding is missing
from state it is re-created by the next apply; if it was removed by hand, `terraform plan` shows it as a pending create.

---

## 3. A failed `terraform apply`

1. **Read the first error, not the last.** Later errors are usually "dependency failed" cascades.
2. **Understand the partial state.** Terraform records each resource as it succeeds, so a failed apply leaves a *partly built*
   environment. This is normal. **Never delete the state file.** Run a fresh plan to see what is left.
3. **The saved plan is now stale.** Re-run the pipeline (new plan, then approval, then apply) instead of re-using the old artifact.

| Error | Meaning | Action |
|---|---|---|
| `API ... has not been used` / `SERVICE_DISABLED` | An API is not enabled | Add it to `local.apis` in `foundation/main.tf`, apply the foundation (human) |
| `Permission ... denied` for `tf-apply` | The apply identity lacks a role | The message names the permission; add the narrowest role in `foundation/main.tf` and document it in `docs/IAM.md` |
| `Error acquiring the state lock` | Another run holds it, or a run crashed | Check the Actions tab. Only if no run is active: `terraform force-unlock LOCK_ID` |
| `Error 409 ... already exists` | The resource exists but is not in state | `terraform import ...` it, or delete the orphan if it is safe |
| IAM / "does not exist" right after creation | Propagation delay | Re-run the apply |
| `Saved plan is stale` | State changed after the plan | Generate a new plan |
| `Failed to get existing workspaces` / backend 403 | Wrong bucket/prefix, or no access to the state bucket | Check `TF_STATE_BUCKET` and the state-bucket grants in the foundation |

**Recovering a damaged state:** the bucket is versioned.
```powershell
gcloud storage ls --all-versions gs://<state-bucket>/retailhub-order-compat/workload/dev/
gcloud storage cp "gs://<state-bucket>/retailhub-order-compat/workload/dev/default.tfstate#<GENERATION>" gs://<state-bucket>/retailhub-order-compat/workload/dev/default.tfstate
```
Then run a plan and read it carefully before applying.

*State, dependencies, IAM:* Terraform builds a graph from resource references (for example the trigger waits for the service).
Where a dependency is not visible in a reference (IAM that must exist before a trigger), the code uses `depends_on`.
Failures upstream therefore explain failures downstream.

---

## 4. Unexpected Terraform drift

**Detect:** `terraform plan -detailed-exitcode` from `infra/workload` exits `2` when reality differs from code.
`terraform plan -refresh-only` shows only "the world changed" differences without proposing config changes.

**Find out who and what:** Admin Activity audit logs are always on and record every change.
```powershell
gcloud logging read "logName:cloudaudit.googleapis.com%2Factivity AND protoPayload.serviceName=run.googleapis.com" --project $P --limit 10 --freshness 7d --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName)"
```
Swap the `serviceName` for `pubsub.googleapis.com`, `storage.googleapis.com`, and so on.

**Decide:** (a) revert, by applying the existing code; or (b) adopt, by changing the code through a pull request so it becomes the new truth.

**Not drift, by design:** the container image and the `client`/`client_version` fields (`ignore_changes`; CI/CD owns the image).

**Blind spot:** IAM bindings are additive (`*_iam_member`). A *removed* binding is detected and re-created. An *extra* binding someone adds by hand
is not detected by Terraform; look for it in the IAM policies and audit logs.

**Do not** hand-edit state. `terraform state rm` and `terraform import` are for deliberate, reviewed corrections only.

---

## 5. A CI/CD deployment failure

First find which job and step failed, then use the table.

| Failing step | Likely cause | Check / fix |
|---|---|---|
| `terraform fmt` | Formatting | Run `terraform fmt -recursive infra` and commit |
| `validate` | Syntax/reference error | `terraform -chdir=infra/workload init -backend=false` then `validate` locally |
| `tflint` | Lint rule | The message names the rule |
| `checkov` | Security finding | Fix it, or add an inline `#checkov:skip=ID:reason` that a reviewer must accept |
| `authenticate` ("rejected by the attribute condition", "unable to acquire impersonated credentials") | Trust mismatch | See the list below |
| `terraform init` (backend) | Wrong bucket/prefix, or no state access | Check variable `TF_STATE_BUCKET` and the foundation's state-bucket grants |
| `terraform plan` permission error | The read-only identity lacks a read permission | The error names it; add the narrowest read role to `tf-plan` |
| `apply` job never starts | Waiting for approval, **or** the plan had no changes (exit 0), which skips apply by design | Approve in the Actions run; otherwise nothing to do |
| `apply` job fails | See scenario 3 | |
| "Plan after apply still proposes changes" | Drift or a non-idempotent setting | Read the diff; fix the configuration or, deliberately, `ignore_changes` |
| `docker push` denied | `gh-deployer` lacks `artifactregistry.writer`, or the repo path/region is wrong | `REPO`, `GCP_REGION`, `GCP_PROJECT_ID` variables |
| `gcloud run deploy` ... `actAs` | Missing `serviceAccountUser` on the runtime account | Grant is in `workload/main.tf` |
| New revision never becomes ready | Container does not start | `gcloud run services logs read $S --region $R --project $P`; it must listen on `$PORT` |

**Authentication failures, checklist:**
1. The job has `permissions: id-token: write`.
2. Variables `WIF_PROVIDER`, `TF_PLAN_SA`, `TF_APPLY_SA`, `DEPLOYER_SA` are set and copied exactly from `terraform output github_repository_variables`.
3. `github_repo` in the foundation matches the repository exactly (case-sensitive).
4. Apply/deploy jobs declare `environment: dev`, and it equals `github_environment` in the foundation.
5. The run is not from a fork (forks get no OIDC token).
6. The binding exists: `gcloud iam service-accounts get-iam-policy tf-apply@$P.iam.gserviceaccount.com`.

**Ordering trap:** the application workflow fails at authentication if the foundation has not been applied or the GitHub variables are missing.

---

## How state, dependencies and IAM shape every scenario

- **State** is Terraform's memory. When state and reality disagree, plans are wrong in confusing ways: resources "already exist", or
  disappear and get re-created. Keep one state per stack, back it up (versioning), lock it, and never edit it casually.
- **Dependencies** decide order. Most failures cascade from one early error; resources that need a service agent's permission, or an
  API, or a propagating IAM grant, fail first and everything after them fails with them.
- **IAM** is both the most common cause and the most delayed: grants take time to propagate, are checked at call time against the
  *caller's* identity (not yours), and each identity here is deliberately narrow. When something is "denied", name the exact identity,
  the exact permission and the exact resource, then grant the smallest role that covers it, in Terraform.
