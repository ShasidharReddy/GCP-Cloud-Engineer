output "network_name" {
  description = "Name of the Shared VPC network."
  value       = google_compute_network.hub.name
}

output "subnets" {
  description = "Shared VPC subnets keyed by attached service project."
  value       = { for project_id, subnet in google_compute_subnetwork.service : project_id => subnet.name }
}

output "host_project" {
  description = "Shared VPC host project ID."
  value       = var.host_project_id
}
