variable "project_id" {
  description = "Google Cloud project ID that hosts the VM deployment."
  type        = string
  default     = "my-production-project"
}

variable "region" {
  description = "Region used for networking and the reserved external IP."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone where the Compute Engine instance and persistent disk will run."
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Machine type for the production VM."
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Size of the additional SSD persistent disk in GB."
  type        = number
  default     = 100
}

variable "network_cidr" {
  description = "Primary subnet CIDR range for the workload VPC."
  type        = string
  default     = "10.10.0.0/24"
}

variable "tags" {
  description = "Network tags attached to the VM for firewall targeting."
  type        = list(string)
  default     = ["single-vm", "http-server", "ssh-access"]
}
