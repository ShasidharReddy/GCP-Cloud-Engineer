output "load_balancer_ip" {
  description = "Global external IP used by the HTTPS load balancer."
  value       = google_compute_global_address.lb.address
}

output "cloud_run_urls" {
  description = "Direct per-region Cloud Run service URLs."
  value       = { for region, service in google_cloud_run_v2_service.app : region => service.uri }
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository name reserved for workload images."
  value       = google_artifact_registry_repository.app.name
}
