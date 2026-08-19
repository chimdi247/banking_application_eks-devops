variable "project_id" {
  description = "GCP project ID."
  type        = string
  default     = "project-522024ff-8338-453d-a3d"
}

variable "region" {
  description = "GCP region (used for the GCS backup bucket)."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (for labeling)."
  type        = string
  default     = "dev"
}

variable "name" {
  description = "Resource name prefix."
  type        = string
  default     = "banking-dev"
}

variable "cluster_name" {
  description = "Existing GKE cluster to read the Workload Identity Pool from."
  type        = string
  default     = "cluster-chimdi"
}

variable "cluster_location" {
  description = "Location (zone or region) of the existing GKE cluster."
  type        = string
  default     = "us-central1-a"
}
