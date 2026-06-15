variable "host_project_id" {
  description = "Project ID of the Shared VPC host project."
  type        = string
  default     = "network-host-prod"
}

variable "service_project_ids" {
  description = "Service projects attached to the Shared VPC host."
  type        = list(string)
  default     = ["app-prod-01", "app-prod-02"]
}

variable "region" {
  description = "Primary region used for subnets, router, and Cloud NAT."
  type        = string
  default     = "us-central1"
}

variable "base_cidr" {
  description = "Base CIDR range that is split into per-service-project subnets."
  type        = string
  default     = "10.40.0.0/20"
}

variable "ingress_source_ranges" {
  description = "Source ranges allowed by the shared ingress firewall policy."
  type        = list(string)
  default     = ["10.0.0.0/8", "35.235.240.0/20"]
}
