# Velero has its OWN state (separate prefix in the same bucket), so it can be
# applied/destroyed independently of the Phase-1 infra state.
terraform {
  backend "gcs" {
    bucket = "banking-platform-velero-tfstate"
    prefix = "dev/velero"
  }
}
