# GCS bucket that stores Velero backups — the Kubernetes object archives
# *and* the kopia file-system volume data (Postgres/Kafka contents).
resource "google_storage_bucket" "this" {
  name     = var.bucket_name
  project  = var.project_id
  location = var.bucket_location

  # Equivalent of the AWS public-access block (all 4 on): no ACLs, no public
  # access, ever — enforced at the bucket level.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Keeps historical versions of backup objects (protection against
  # overwrite/corruption) — same intent as S3 versioning.
  versioning {
    enabled = true
  }

  force_destroy = false
}

# The Google Service Account the Velero pod impersonates via Workload
# Identity — no static GCP keys in the cluster.
resource "google_service_account" "velero" {
  project      = var.project_id
  account_id   = "${var.name}-velero"
  display_name = "Velero backup/restore (${var.name})"
}

# S3-equivalent permissions, scoped to the backup bucket only:
# GetObject, PutObject, DeleteObject, ListBucket, AbortMultipartUpload,
# ListMultipartUploadParts all map onto roles/storage.objectAdmin on GCS.
resource "google_storage_bucket_iam_member" "velero_bucket" {
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.velero.email}"
}

# EC2-snapshot-equivalent permissions (account-wide), for the optional
# CSI/Persistent-Disk snapshot mode: describe/create/delete disks and
# snapshots. Custom role keeps this to the minimum set rather than a broad
# predefined role.
resource "google_project_iam_custom_role" "velero_snapshot" {
  project     = var.project_id
  role_id     = replace("${var.name}_velero_snapshot", "-", "_")
  title       = "${var.name} Velero snapshot permissions"
  description = "Minimum Compute Engine disk/snapshot permissions for Velero PV backup/restore."

  permissions = [
    "compute.disks.get",
    "compute.disks.list",
    "compute.disks.createSnapshot",
    "compute.snapshots.get",
    "compute.snapshots.list",
    "compute.snapshots.create",
    "compute.snapshots.delete",
    "compute.snapshots.setLabels",
    "compute.zoneOperations.get",
    "compute.globalOperations.get",
  ]
}

resource "google_project_iam_member" "velero_snapshot" {
  project = var.project_id
  role    = google_project_iam_custom_role.velero_snapshot.id
  member  = "serviceAccount:${google_service_account.velero.email}"
}

# Workload Identity trust (who can assume the GSA): only the velero
# ServiceAccount in the velero namespace, via the cluster's Workload
# Identity Pool — the GKE equivalent of the AWS IRSA OIDC trust policy.
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.velero.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.workload_identity_pool}[${var.k8s_namespace}/${var.k8s_service_account}]"
}
