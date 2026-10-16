# IAM design and rationale

Principles: one identity per job, grants on the **resource** rather than the project wherever possible,
no `Editor`/`Owner` anywhere, no service-account keys, and every binding written in Terraform with a reason.

## Identities

| Identity | Created in | Used by |
|---|---|---|
| `compat-processor` (runtime) | workload | The Cloud Run service |
| `compat-trigger` | workload | EventArc, to call Cloud Run |
| `tf-plan` | foundation | Pull-request plans (read-only) |
| `tf-apply` | foundation | Applying the workload stack |
| `gh-deployer` | foundation (grants in workload) | Pushing and deploying the app image |
| GCS service agent | Google | Cloud Storage publishing object events |
| Pub/Sub service agent | Google | Forwarding undeliverable messages to the dead-letter topic |

## Bindings and why each exists

### Runtime identity `compat-processor` (no project-level roles at all)
| Role | On | Why |
|---|---|---|
| `roles/storage.objectViewer` | the input bucket | Download the RetailHub JSON file the event points to. Read-only; it cannot modify or delete source data. |
| `roles/pubsub.publisher` | output topic | Publish valid CloudEvents. |
| `roles/pubsub.publisher` | dead-letter topic | Publish records that failed transform or validation. |

### Event path
| Identity | Role | On | Why |
|---|---|---|---|
| `compat-trigger` | `roles/run.invoker` | the Cloud Run service | The service rejects unauthenticated callers. This is the *only* identity allowed to call it. |
| `compat-trigger` | `roles/eventarc.eventReceiver` | project | EventArc requires the trigger identity to be allowed to receive events. |
| GCS service agent | `roles/pubsub.publisher` | project | Cloud Storage delivers object events through Pub/Sub; without this the trigger silently receives nothing. |

### Dead-letter delivery
| Identity | Role | On | Why |
|---|---|---|---|
| Pub/Sub service agent | `roles/pubsub.publisher` | dead-letter topic | Pub/Sub itself, not our app, writes the undeliverable message to the topic. |
| Pub/Sub service agent | `roles/pubsub.subscriber` | output subscription | It must acknowledge the failed message on the source subscription so it is removed once forwarded. |

### Deployment identity `gh-deployer` (application deploys)
| Role | On | Why |
|---|---|---|
| `roles/artifactregistry.writer` | the image repository | Push the built image. Cannot touch other repositories. |
| `roles/run.developer` | the Cloud Run service | Create a new revision. Cannot change who may invoke the service (that needs `run.admin`). |
| `roles/iam.serviceAccountUser` | the runtime account | Cloud Run requires the deployer to be allowed to "act as" the runtime identity. Without it deploys fail with a `iam.serviceAccounts.actAs` error. |

### Terraform identities
| Identity | Role | On | Why |
|---|---|---|---|
| `tf-plan` | `roles/viewer` | project | Refresh and read every resource to compute a plan. |
| `tf-plan` | `roles/iam.securityReviewer` | project | Read IAM policies; `viewer` cannot, and the stack manages many IAM bindings. |
| `tf-plan` | `roles/storage.objectViewer`, `roles/storage.legacyBucketReader` | state bucket | Read state (and the bucket's metadata/listing) so it can diff. It cannot write state. |
| `tf-apply` | `roles/run.admin` | project | Create the service and manage its invoker binding. |
| `tf-apply` | `roles/pubsub.admin` | project | Topics, subscriptions and their IAM. |
| `tf-apply` | `roles/storage.admin` | project | The input bucket and its IAM. |
| `tf-apply` | `roles/artifactregistry.admin` | project | The image repository and its IAM. |
| `tf-apply` | `roles/eventarc.admin` | project | The trigger. |
| `tf-apply` | `roles/iam.serviceAccountAdmin` | project | Create the runtime and trigger accounts. |
| `tf-apply` | `roles/iam.serviceAccountUser` | project | Attach those accounts to Cloud Run and EventArc (actAs). |
| `tf-apply` | `roles/resourcemanager.projectIamAdmin` | project | The two project-level bindings (`eventReceiver`, GCS agent publisher). |
| `tf-apply` | `roles/storage.objectAdmin`, `roles/storage.legacyBucketReader` | state bucket | Read/write state and take the lock. |

`tf-apply` has no API-enablement or project-creation rights: those belong to the foundation, which a human runs.

## How GitHub is trusted (no keys)
1. The workload identity **provider** accepts tokens issued for exactly one repository (`assertion.repository`).
2. Each service account then carries its own rule about *which jobs* may impersonate it:

| Service account | Who may impersonate it | Effect |
|---|---|---|
| `tf-plan` | Any workflow run in this repository | Pull-request plans work. Harmless: read-only. |
| `tf-apply` | Only jobs declaring `environment: dev` | Reaching it requires reviewer approval and the `main`-only deployment rule. |
| `gh-deployer` | Only jobs declaring `environment: dev` | Same gate for application deploys. |

A pull request therefore cannot apply infrastructure or deploy: it can only obtain the read-only identity.

## Known limitations (stated honestly)
- `tf-apply` holds `projectIamAdmin` and `serviceAccountAdmin`, which can in principle grant itself more rights inside the project.
  That is inherent to Terraform managing IAM. It is contained by the approval gate, the `main`-only rule, and the dedicated project.
  A further step would be IAM conditions limiting which roles it may grant.
- `roles/viewer` is broad for reading. It is read-only and scoped to one dedicated project.
- All bindings use the additive `*_iam_member` resources. Terraform will not remove a binding someone else adds by hand;
  it will re-create one that is removed. Audit logs, not Terraform, reveal extra grants.
- The person who runs the foundation holds powerful rights (org project creation, billing). Those are never given to CI.
