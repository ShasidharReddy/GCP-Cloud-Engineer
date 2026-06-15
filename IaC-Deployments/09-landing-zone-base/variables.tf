variable "organization_id" {
  description = "Organization ID used for folders, policies, and essential contacts."
  type        = string
  default     = "123456789012"
}

variable "customer_id" {
  description = "Cloud Identity customer ID used by the domain restricted sharing policy."
  type        = string
  default     = "C0123abc"
}

variable "billing_account_id" {
  description = "Billing account identifier in the form billingAccounts/XXXXXX-XXXXXX-XXXXXX."
  type        = string
  default     = "billingAccounts/000000-000000-000000"
}

variable "bootstrap_project_id" {
  description = "Bootstrap/admin project created in the Bootstrap folder."
  type        = string
  default     = "bootstrap-admin-prod"
}

variable "shared_vpc_project_id" {
  description = "Project ID of the Common-folder Shared VPC host project."
  type        = string
  default     = "common-network-prod"
}

variable "logging_project_id" {
  description = "Central logging project ID."
  type        = string
  default     = "central-logging-prod"
}

variable "production_project_id" {
  description = "Example production application project ID."
  type        = string
  default     = "prod-app-001"
}

variable "nonproduction_project_id" {
  description = "Example non-production application project ID."
  type        = string
  default     = "nonprod-app-001"
}

variable "sandbox_project_id" {
  description = "Example sandbox project ID."
  type        = string
  default     = "sandbox-app-001"
}

variable "default_region" {
  description = "Default region used for foundational shared networking."
  type        = string
  default     = "us-central1"
}

variable "platform_admin_member" {
  description = "Platform administrator principal granted key bootstrap IAM roles."
  type        = string
  default     = "group:platform-admins@example.com"
}

variable "essential_contact_email" {
  description = "Essential contact email address for organization notices."
  type        = string
  default     = "security@example.com"
}

variable "monthly_budget_usd" {
  description = "Monthly bootstrap budget amount in USD."
  type        = number
  default     = 5000
}
