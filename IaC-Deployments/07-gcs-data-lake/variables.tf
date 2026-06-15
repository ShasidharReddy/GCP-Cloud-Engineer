variable "project_id" {
  description = "Project ID that hosts the data lake resources."
  type        = string
  default     = "my-production-project"
}

variable "region" {
  description = "Primary region for buckets, KMS, and Dataflow."
  type        = string
  default     = "us-central1"
}

variable "data_engineer_members" {
  description = "IAM members that require access to GCS and BigQuery data assets."
  type        = list(string)
  default     = ["group:data-engineers@example.com"]
}

variable "run_dataflow_job" {
  description = "Set to true to launch the Dataflow template job during apply."
  type        = bool
  default     = false
}

variable "dataflow_template_gcs_path" {
  description = "GCS path to a Dataflow template used for ingestion or transformation."
  type        = string
  default     = "gs://dataflow-templates-us-central1/latest/GCS_Text_to_BigQuery"
}

variable "dataflow_zone" {
  description = "Zone used when launching the Dataflow job."
  type        = string
  default     = "us-central1-a"
}

variable "dataflow_service_account_email" {
  description = "Service account used by the optional Dataflow job."
  type        = string
  default     = "dataflow-runner@my-production-project.iam.gserviceaccount.com"
}

variable "access_policy_id" {
  description = "Access Context Manager policy ID used for the optional VPC Service Controls perimeter."
  type        = string
  default     = ""
}

variable "perimeter_name" {
  description = "Name of the optional service perimeter protecting storage and analytics APIs."
  type        = string
  default     = "datalake-perimeter"
}
