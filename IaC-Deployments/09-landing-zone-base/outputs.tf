output "folder_ids" {
  description = "Created landing zone folder IDs."
  value = {
    bootstrap     = google_folder.bootstrap.folder_id
    common        = google_folder.common.folder_id
    production    = google_folder.production.folder_id
    nonproduction = google_folder.nonproduction.folder_id
    sandbox       = google_folder.sandbox.folder_id
  }
}

output "project_ids" {
  description = "Core landing zone project IDs."
  value = {
    bootstrap  = google_project.bootstrap.project_id
    shared_vpc = google_project.shared_vpc.project_id
    logging    = google_project.logging.project_id
    production = google_project.prod_app.project_id
    nonprod    = google_project.nonprod_app.project_id
    sandbox    = google_project.sandbox.project_id
  }
}

output "shared_vpc_network" {
  description = "Shared VPC network name created in the Common folder."
  value       = google_compute_network.shared.name
}
