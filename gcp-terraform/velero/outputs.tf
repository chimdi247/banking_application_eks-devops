output "velero_bucket" {
  description = "GCS bucket holding Velero backups."
  value       = module.velero.bucket_name
}

output "velero_gsa_email" {
  description = "Google Service Account email the velero KSA impersonates via Workload Identity (annotate it on the ServiceAccount)."
  value       = module.velero.gsa_email
}
