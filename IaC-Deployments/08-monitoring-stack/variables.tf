variable "project_id" {
  description = "Project ID used for logging, monitoring, and budget resources."
  type        = string
  default     = "my-production-project"
}

variable "notification_email" {
  description = "Primary email notification target for alerting and budget updates."
  type        = string
  default     = "ops@example.com"
}

variable "pagerduty_service_name" {
  description = "PagerDuty service name associated with the integration key."
  type        = string
  default     = "platform-oncall"
}

variable "pagerduty_service_key" {
  description = "PagerDuty integration key stored in Terraform state unless a write-only variant is used."
  type        = string
  default     = "replace-me"
  sensitive   = true
}

variable "slack_channel_name" {
  description = "Slack channel used by the Monitoring notification channel, including the leading #."
  type        = string
  default     = "#incidents"
}

variable "slack_auth_token" {
  description = "Slack bot token used by the native Monitoring Slack notification channel."
  type        = string
  default     = "replace-me"
  sensitive   = true
}

variable "uptime_host" {
  description = "Public hostname used by the uptime check configuration."
  type        = string
  default     = "app.example.com"
}

variable "billing_account_id" {
  description = "Billing account identifier in the form billingAccounts/XXXXXX-XXXXXX-XXXXXX."
  type        = string
  default     = "billingAccounts/000000-000000-000000"
}

variable "monthly_budget_usd" {
  description = "Monthly budget amount used for billing alert thresholds."
  type        = number
  default     = 1000
}

variable "bigquery_location" {
  description = "BigQuery location used for centralized log analytics."
  type        = string
  default     = "US"
}

variable "bucket_location" {
  description = "Storage location for the archival logging bucket."
  type        = string
  default     = "US"
}
