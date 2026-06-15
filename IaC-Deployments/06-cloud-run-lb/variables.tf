variable "project_id" {
  description = "Project ID used for the Cloud Run edge deployment."
  type        = string
  default     = "my-production-project"
}

variable "regions" {
  description = "Cloud Run regions used for the active/active deployment."
  type        = list(string)
  default     = ["us-central1", "us-east1"]
}

variable "domains" {
  description = "Custom domains bound to the managed SSL certificate."
  type        = list(string)
  default     = ["app.example.com"]
}

variable "container_image" {
  description = "Container image deployed to both Cloud Run services."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "allow_unauthenticated" {
  description = "When true, grants the public `run.invoker` role to all users."
  type        = bool
  default     = true
}

variable "min_instances" {
  description = "Minimum container instances kept warm per region."
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of container instances per region."
  type        = number
  default     = 10
}

variable "base_cidr" {
  description = "Subnet range used for regional serverless connectivity subnets."
  type        = string
  default     = "10.60.0.0/20"
}

variable "connector_cidr" {
  description = "CIDR range split across Serverless VPC Access connectors."
  type        = string
  default     = "10.61.0.0/20"
}
