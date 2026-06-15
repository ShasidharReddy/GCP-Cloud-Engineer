output "cluster_name" {
  description = "Name of the created GKE cluster."
  value       = var.enable_autopilot ? google_container_cluster.autopilot[0].name : google_container_cluster.standard[0].name
}

output "cluster_endpoint" {
  description = "Control plane endpoint for the created GKE cluster."
  value       = var.enable_autopilot ? google_container_cluster.autopilot[0].endpoint : google_container_cluster.standard[0].endpoint
}

output "network_name" {
  description = "Custom VPC name used by the GKE deployment."
  value       = google_compute_network.gke.name
}
