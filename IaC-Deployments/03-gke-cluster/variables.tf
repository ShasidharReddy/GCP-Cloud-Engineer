variable "project_id" {
  description = "Project ID where the GKE cluster is created."
  type        = string
  default     = "my-production-project"
}

variable "region" {
  description = "Primary regional location for the cluster."
  type        = string
  default     = "us-central1"
}

variable "enable_autopilot" {
  description = "When true, creates an Autopilot cluster instead of the Standard cluster and node pools."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protects the cluster from accidental deletion."
  type        = bool
  default     = true
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR for worker nodes and control plane connectivity."
  type        = string
  default     = "10.30.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range used for pod IP aliases."
  type        = string
  default     = "10.31.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range used for Kubernetes service IPs."
  type        = string
  default     = "10.32.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "Dedicated CIDR used by the GKE control plane."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDR ranges allowed to reach the private control plane endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "203.0.113.0/24"
      display_name = "corp-egress"
    }
  ]
}

variable "default_node_machine_type" {
  description = "Machine type for the default general-purpose node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "highmem_node_machine_type" {
  description = "Machine type for the high-memory node pool."
  type        = string
  default     = "e2-highmem-4"
}

variable "spot_node_machine_type" {
  description = "Machine type for the Spot-based node pool."
  type        = string
  default     = "e2-standard-4"
}
