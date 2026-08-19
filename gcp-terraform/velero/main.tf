# Standalone root for Velero's GCP resources. Reads the EXISTING cluster's
# Workload Identity config via a data source (no dependency on the Phase-1
# state), then calls the reusable velero module. Apply this on its own:
# `cd terraform/velero && terraform apply`.

data "google_project" "current" {}

# Look up the running cluster to confirm Workload Identity is enabled and to
# derive the pool used for the GSA <-> KSA binding.
data "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.cluster_location
  project  = var.project_id
}

locals {
  # Workload Identity Pool is always "<project-id>.svc.id.goog" once WI is
  # enabled on the cluster (workload_identity_config.workload_pool confirms it).
  workload_identity_pool = data.google_container_cluster.this.workload_identity_config[0].workload_pool
  bucket_name            = "banking-velero-backups-${data.google_project.current.number}"
}

module "velero" {
  source = "../modules/velero"

  name                   = var.name
  project_id             = var.project_id
  bucket_name            = local.bucket_name
  bucket_location        = var.region
  workload_identity_pool = local.workload_identity_pool
  k8s_namespace          = "velero"
  k8s_service_account    = "velero"
}
