variable "project_id" {
  description = "Google Cloud project hosting the HA workload."
  type        = string
  default     = "my-production-project"
}

variable "regions" {
  description = "Two active regions used for the stateless web tier and storage replication."
  type        = list(string)
  default     = ["us-central1", "europe-west1"]
}

variable "network_cidr" {
  description = "Base CIDR used to derive per-region subnets."
  type        = string
  default     = "10.20.0.0/20"
}

variable "instance_count" {
  description = "Baseline number of instances per regional managed instance group."
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type used by the regional instance templates."
  type        = string
  default     = "e2-medium"
}

variable "domains" {
  description = "Domain names attached to the managed SSL certificate for the global HTTPS load balancer."
  type        = list(string)
  default     = ["ha.example.com"]
}

variable "service_account_email" {
  description = "Service account email attached to the web tier VMs."
  type        = string
  default     = "terraform-runtime@my-production-project.iam.gserviceaccount.com"
}
