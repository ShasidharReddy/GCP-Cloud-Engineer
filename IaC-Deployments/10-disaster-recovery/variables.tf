variable "project_id" {
  description = "Project ID that hosts the disaster recovery deployment."
  type        = string
  default     = "my-production-project"
}

variable "primary_region" {
  description = "Primary region for the active workload and HA database."
  type        = string
  default     = "us-central1"
}

variable "secondary_region" {
  description = "Secondary region used for warm DR capacity and replica placement."
  type        = string
  default     = "us-east1"
}

variable "machine_type" {
  description = "Machine type used by the web tier in both regions."
  type        = string
  default     = "e2-medium"
}

variable "primary_instance_count" {
  description = "Baseline instance count in the primary regional MIG."
  type        = number
  default     = 2
}

variable "secondary_instance_count" {
  description = "Warm standby instance count in the secondary regional MIG."
  type        = number
  default     = 1
}

variable "base_cidr" {
  description = "Base CIDR used to derive primary and secondary regional subnets."
  type        = string
  default     = "10.70.0.0/20"
}

variable "dns_zone_name" {
  description = "Authoritative public DNS zone name used for failover routing."
  type        = string
  default     = "example-dr.com"
}

variable "backup_endpoint_ip" {
  description = "Secondary public IP used by DNS failover when the primary endpoint is unhealthy."
  type        = string
  default     = "198.51.100.20"
}

variable "runtime_service_account_email" {
  description = "Service account used by the workload VMs and DR Cloud Function."
  type        = string
  default     = "terraform-runtime@my-production-project.iam.gserviceaccount.com"
}
