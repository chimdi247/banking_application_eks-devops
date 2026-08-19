# Velero — GCP resources (standalone Terraform stack)

This is an **optional, standalone** Terraform stack that provisions the **GCP
resources Velero needs** for cluster backup & disaster recovery on GKE. It is
**deliberately separate** from the core infrastructure in
[`../environments/dev`](../environments/dev):

- It has its **own state file** (`dev/velero` prefix in the shared state bucket),
  so it can be applied and destroyed **independently** of the cluster.
- A normal core-infra `terraform apply` (in `environments/dev`) **never** creates
  these resources — Velero is opt-in.
- It reads the **already-running cluster** via a data source (no dependency on
  the Phase-1 stack's outputs).

> This stack creates only the **GCP side**. Installing the Velero **server**
> (Helm chart / Argo CD app), taking backups, schedules, and restores are covered
> in [`docs/gcp/08-velero.md`](../../docs/gcp/08-velero.md).

---

## What Terraform creates here

Applying this stack (`terraform apply`) creates **6 resources** via the
[`../modules/velero`](../modules/velero) module:

| # | Resource (Terraform) | GCP resource | Purpose |
|---|----------------------|---------------|---------|
| 1 | `google_storage_bucket.this` | **GCS bucket** `banking-velero-backups-<project-number>` | Stores Velero backups — the Kubernetes object archives **and** the kopia file-system volume data (Postgres/Kafka contents). |
| 2 | `google_storage_bucket.this` (`versioning` block) | GCS **object versioning** (Enabled) | Keeps historical versions of backup objects (protection against overwrite/corruption). |
| 3 | `google_storage_bucket.this` (`public_access_prevention`) | GCS **public access prevention** (`enforced`) + uniform bucket-level access | Ensures backups are never publicly exposed. |
| 4 | `google_service_account.velero` | **Service account** `<name>-velero` | The identity Velero runs as. |
| 5 | `google_storage_bucket_iam_member.velero_bucket` + `google_project_iam_custom_role.velero_snapshot` / `google_project_iam_member.velero_snapshot` | **IAM bindings** | Grants Velero: object read/write/list on the backup bucket **+** Compute Engine disk/snapshot permissions (for the optional CSI/Persistent-Disk snapshot mode). |
| 6 | `google_service_account_iam_member.workload_identity` | **Workload Identity binding** | Lets the `velero/velero` KSA impersonate the GSA — no static GCP keys in the cluster. |

Plus **read-only data sources** (create nothing):

| Data source | Why |
|-------------|-----|
| `google_project.current` | Get the GCP project number (used in the bucket name). |
| `google_container_cluster.this` (`cluster-chimdi`) | Read the cluster's **Workload Identity Pool**, used to build the GSA↔KSA binding. This is how the stack "finds" the cluster without needing the Phase-1 state. |

### The IAM permissions granted (summary)
```
GCS  (on the backup bucket only):  roles/storage.objectAdmin
                                    (get, create, delete, list objects; multipart handled natively)
Compute Engine (project-wide, for snapshots): disks.get/list, disks.createSnapshot,
                                    snapshots.get/list/create/delete/setLabels,
                                    zoneOperations.get, globalOperations.get
```

### Workload Identity trust (who can assume the GSA)
Only the `velero` ServiceAccount in the `velero` namespace, via the cluster's
Workload Identity Pool:
```
serviceAccount:<project-id>.svc.id.goog[velero/velero]
```

---

## What it does NOT do
- ❌ Does **not** install the Velero server, node-agent, or CRDs (that's the Helm
  chart / Argo app — see doc 08).
- ❌ Does **not** touch the GKE cluster, VPC, node pools, or any Phase-1 infra.
- ❌ Does **not** take backups or schedules (Velero CLI / `Schedule` CRD do that).

---

## Files in this stack
| File | Role |
|------|------|
| `backend.tf` | GCS remote state — prefix `dev/velero`, native GCS state locking. |
| `providers.tf` | Google provider + default labels (`component = velero`). |
| `versions.tf` | Terraform ≥ 1.10, `hashicorp/google ~> 6.0`. |
| `variables.tf` | `project_id`, `region`, `environment`, `name`, `cluster_name`, `cluster_location` (defaults target `cluster-chimdi` / `us-central1-a`). |
| `main.tf` | Data-source lookups + the `module "velero"` call. |
| `outputs.tf` | `velero_bucket`, `velero_gsa_email`. |

---

## Prerequisites
- The **GKE cluster `cluster-chimdi` exists** with **Workload Identity enabled**
  (this stack reads its Workload Identity Pool).
- The **state bucket** `banking-platform-tfstate-734665195338` exists (created in
  Phase 1).
- `gcloud` authenticated with permissions to manage IAM and storage; Terraform ≥ 1.10.

## Usage
```bash
cd terraform/velero

terraform init          # configures the GCS backend (own state: dev/velero)
terraform plan          # review: 6 resources to add
terraform apply         # create the bucket + service account + IAM bindings

# Outputs used by the Velero install (doc 08):
terraform output velero_gsa_email   # -> annotate on the velero ServiceAccount
terraform output velero_bucket      # -> Velero backupStorageLocation bucket
```

### Outputs and where they're used
| Output | Used in |
|--------|---------|
| `velero_gsa_email` | The Velero Helm/Argo values, and the KSA annotation: `iam.gke.io/gcp-service-account: <email>` on the `velero` ServiceAccount. |
| `velero_bucket` | The Velero `backupStorageLocation.bucket`. |

### Wiring up the KSA (after apply)
```bash
kubectl -n velero annotate serviceaccount velero \
  iam.gke.io/gcp-service-account=$(terraform output -raw velero_gsa_email)
```

## Teardown (independent of the cluster)
```bash
cd terraform/velero
terraform destroy
```
> GCS won't delete a non-empty bucket unless `force_destroy` is set. If you want
> it gone, empty it first:
> `gsutil -m rm -r gs://banking-velero-backups-<project-number>/**`
> (Keep the backups if you might restore into a rebuilt cluster — that's the point of DR.)

---

➡️ Full backup/restore walkthrough: [`docs/gcp/08-velero.md`](../../docs/gcp/08-velero.md)
