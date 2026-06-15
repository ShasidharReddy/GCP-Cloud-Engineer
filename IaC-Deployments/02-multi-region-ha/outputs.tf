output "global_lb_ip" {
  description = "Global anycast IP for the HTTPS load balancer."
  value       = google_compute_global_address.lb.address
}

output "mig_names" {
  description = "Regional managed instance group names keyed by region."
  value       = { for region, mig in google_compute_region_instance_group_manager.mig : region => mig.name }
}

output "bucket_replication" {
  description = "Origin and replica GCS buckets used by the HA deployment."
  value = {
    origin  = google_storage_bucket.origin.name
    replica = google_storage_bucket.replica.name
  }
}
