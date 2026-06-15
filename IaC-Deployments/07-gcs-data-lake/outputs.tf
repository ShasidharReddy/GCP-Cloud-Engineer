output "bucket_names" {
  description = "Names of the data lake storage tiers."
  value = {
    standard = google_storage_bucket.standard.name
    nearline = google_storage_bucket.nearline.name
    coldline = google_storage_bucket.coldline.name
  }
}

output "dataset_id" {
  description = "BigQuery dataset used for lake analytics."
  value       = google_bigquery_dataset.lake.dataset_id
}

output "kms_key" {
  description = "CMEK key protecting buckets and the dataset."
  value       = google_kms_crypto_key.lake.id
}
