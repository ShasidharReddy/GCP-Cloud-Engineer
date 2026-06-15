output "primary_connection_name" {
  description = "Primary Cloud SQL connection name."
  value       = google_sql_database_instance.primary.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the primary instance."
  value       = google_sql_database_instance.primary.private_ip_address
}

output "auth_proxy_command" {
  description = "Cloud SQL Auth Proxy bootstrap command for the primary instance."
  value       = "./cloud-sql-proxy --private-ip ${google_sql_database_instance.primary.connection_name}"
}

output "secret_name" {
  description = "Secret Manager secret that stores the generated administrator password."
  value       = google_secret_manager_secret.db_password.secret_id
}
