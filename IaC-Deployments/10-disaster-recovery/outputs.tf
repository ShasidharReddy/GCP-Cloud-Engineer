output "primary_lb_ip" {
  description = "Primary load balancer IP for the DR web tier."
  value       = google_compute_global_address.primary.address
}

output "dns_record" {
  description = "Failover DNS record name used by clients."
  value       = google_dns_record_set.app.name
}

output "cloud_sql_replica_name" {
  description = "Cross-region replica name that can be promoted during failover."
  value       = google_sql_database_instance.replica.name
}

output "backup_function" {
  description = "Cloud Function resource name for DR backup orchestration."
  value       = google_cloudfunctions2_function.backup_orchestrator.name
}
