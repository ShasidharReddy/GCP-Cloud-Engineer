terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  labels = {
    environment = "production"
    project     = "07-gcs-data-lake"
    managed_by  = "terraform"
  }
}

resource "google_project_service" "services" {
  for_each = toset([
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "dataflow.googleapis.com",
    "cloudkms.googleapis.com",
    "accesscontextmanager.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_kms_key_ring" "lake" {
  name     = "lake-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "lake" {
  name            = "lake-key"
  key_ring        = google_kms_key_ring.lake.id
  rotation_period = "7776000s"
  labels          = local.labels
}

resource "google_storage_bucket" "standard" {
  name                        = "${var.project_id}-lake-standard"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  labels                      = local.labels

  encryption {
    default_kms_key_name = google_kms_crypto_key.lake.id
  }

  versioning { enabled = true }

  retention_policy {
    retention_period = 2592000
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

resource "google_storage_bucket" "nearline" {
  name                        = "${var.project_id}-lake-nearline"
  location                    = var.region
  storage_class               = "NEARLINE"
  uniform_bucket_level_access = true
  labels                      = local.labels

  encryption {
    default_kms_key_name = google_kms_crypto_key.lake.id
  }

  versioning { enabled = true }
}

resource "google_storage_bucket" "coldline" {
  name                        = "${var.project_id}-lake-coldline"
  location                    = var.region
  storage_class               = "COLDLINE"
  uniform_bucket_level_access = true
  labels                      = local.labels

  encryption {
    default_kms_key_name = google_kms_crypto_key.lake.id
  }

  versioning { enabled = true }
}

resource "google_bigquery_dataset" "lake" {
  dataset_id                 = "data_lake"
  location                   = upper(substr(var.region, 0, 2)) == "EU" ? "EU" : "US"
  delete_contents_on_destroy = false
  labels                     = local.labels

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.lake.id
  }
}

resource "google_bigquery_table" "external_raw" {
  dataset_id = google_bigquery_dataset.lake.dataset_id
  table_id   = "raw_events_external"

  external_data_configuration {
    autodetect    = true
    source_format = "NEWLINE_DELIMITED_JSON"
    source_uris   = ["gs://${google_storage_bucket.standard.name}/raw/*.json"]
  }
}

resource "google_storage_bucket_iam_binding" "data_engineers" {
  for_each = {
    standard = google_storage_bucket.standard.name
    nearline = google_storage_bucket.nearline.name
    coldline = google_storage_bucket.coldline.name
  }

  bucket  = each.value
  role    = "roles/storage.objectAdmin"
  members = var.data_engineer_members
}

resource "google_bigquery_dataset_iam_binding" "data_engineers" {
  dataset_id = google_bigquery_dataset.lake.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = var.data_engineer_members
}

resource "google_dataflow_job" "template" {
  count                 = var.run_dataflow_job ? 1 : 0
  name                  = "lake-ingestion-job"
  template_gcs_path     = var.dataflow_template_gcs_path
  temp_gcs_location     = "gs://${google_storage_bucket.standard.name}/tmp"
  zone                  = var.dataflow_zone
  on_delete             = "cancel"
  service_account_email = var.dataflow_service_account_email
  parameters = {
    inputFilePattern = "gs://${google_storage_bucket.standard.name}/raw/*.json"
    outputTable      = "${var.project_id}:${google_bigquery_dataset.lake.dataset_id}.curated_events"
  }
}

resource "google_access_context_manager_service_perimeter" "lake" {
  count  = var.access_policy_id == "" ? 0 : 1
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/${var.perimeter_name}"
  title  = var.perimeter_name

  status {
    resources = ["projects/${data.google_project.current.number}"]
    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com"
    ]
  }
}
