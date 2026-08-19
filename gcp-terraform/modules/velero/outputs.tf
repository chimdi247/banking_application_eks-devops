output "bucket_name" {
  description = "GCS bucket holding Velero backups."
  value       = google_storage_bucket.this.name
}

output "gsa_email" {
  description = "Google Service Account email assumed by the velero KSA (annotate it on the ServiceAccount)."
  value       = google_service_account.velero.email
}
