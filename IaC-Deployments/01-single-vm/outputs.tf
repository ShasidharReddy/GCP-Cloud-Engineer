output "external_ip" {
  description = "Reserved static external IP of the VM."
  value       = google_compute_address.static_ip.address
}

output "internal_ip" {
  description = "Primary internal IP assigned to the VM."
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "instance_name" {
  description = "Name of the Compute Engine instance."
  value       = google_compute_instance.vm.name
}

output "self_link" {
  description = "Self link of the Compute Engine instance."
  value       = google_compute_instance.vm.self_link
}
