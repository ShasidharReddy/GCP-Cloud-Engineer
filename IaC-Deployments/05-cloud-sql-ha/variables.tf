variable "project_id" {
  description = "Project ID hosting the Cloud SQL deployment."
  type        = string
  default     = "my-production-project"
}

variable "region" {
  description = "Primary region for the HA Cloud SQL instance."
  type        = string
  default     = "us-central1"
}

variable "dr_region" {
  description = "Secondary region for the cross-region read replica."
  type        = string
  default     = "us-east1"
}

variable "database_version" {
  description = "Cloud SQL engine/version, for example POSTGRES_16 or MYSQL_8_0."
  type        = string
  default     = "POSTGRES_16"
}

variable "tier" {
  description = "Machine tier for the HA primary instance."
  type        = string
  default     = "db-custom-2-7680"
}

variable "replica_tier" {
  description = "Machine tier for local and cross-region replicas."
  type        = string
  default     = "db-custom-2-7680"
}

variable "disk_size_gb" {
  description = "Primary instance SSD size in GB."
  type        = number
  default     = 200
}

variable "network_cidr" {
  description = "Subnet CIDR allocated to the private services network."
  type        = string
  default     = "10.50.0.0/24"
}

variable "deletion_protection" {
  description = "Prevents accidental deletion of Cloud SQL instances."
  type        = bool
  default     = true
}
