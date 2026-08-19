variable "name" {
  description = "Resource name prefix (e.g. banking-dev)."
  type        = string
}

variable "project_id" {
  description = "GCP project ID that owns the bucket, GSA, and snapshot permissions."
  type        = string
}

variable "bucket_name" {
  description = "Globally-unique GCS bucket name for Velero backups."
  type        = string
}

variable "bucket_location" {
  description = "GCS bucket location (region or multi-region, e.g. us-central1)."
  type        = string
}

variable "workload_identity_pool" {
  description = "Cluster's Workload Identity Pool, formatted <project-id>.svc.id.goog."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace the velero ServiceAccount lives in."
  type        = string
  default     = "velero"
}

variable "k8s_service_account" {
  description = "Kubernetes ServiceAccount name Velero runs as."
  type        = string
  default     = "velero"
}
