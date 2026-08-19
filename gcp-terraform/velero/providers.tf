provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project     = "banking-platform"
    environment = var.environment
    managed_by  = "terraform"
    component   = "velero"
  }
}
