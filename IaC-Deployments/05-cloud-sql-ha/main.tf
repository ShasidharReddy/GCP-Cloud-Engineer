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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
    project     = "05-cloud-sql-ha"
    managed_by  = "terraform"
  }
  is_postgres = startswith(var.database_version, "POSTGRES")
  is_mysql    = startswith(var.database_version, "MYSQL")
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "sql" {
  name                    = "cloudsql-private-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "sql" {
  name                     = "cloudsql-private-subnet"
  region                   = var.region
  network                  = google_compute_network.sql.id
  ip_cidr_range            = var.network_cidr
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_ip" {
  name          = "cloudsql-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.sql.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.sql.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!@#%^*-_=+"
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "cloudsql-admin-password"
  labels    = local.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_sql_database_instance" "primary" {
  provider            = google-beta
  name                = "prod-sql-primary"
  database_version    = var.database_version
  region              = var.region
  deletion_protection = var.deletion_protection
  root_password       = random_password.db_password.result

  settings {
    tier                        = var.tier
    availability_type           = "REGIONAL"
    disk_type                   = "PD_SSD"
    disk_size                   = var.disk_size_gb
    user_labels                 = local.labels
    connector_enforcement       = "REQUIRED"
    deletion_protection_enabled = var.deletion_protection

    backup_configuration {
      enabled                        = true
      binary_log_enabled             = local.is_mysql
      point_in_time_recovery_enabled = local.is_postgres
      start_time                     = "02:00"

      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.sql.id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    dynamic "database_flags" {
      for_each = local.is_postgres ? [1] : []
      content {
        name  = "cloudsql.iam_authentication"
        value = "on"
      }
    }

    dynamic "database_flags" {
      for_each = local.is_mysql ? [1] : []
      content {
        name  = "cloudsql_iam_authentication"
        value = "on"
      }
    }

    dynamic "database_flags" {
      for_each = local.is_mysql ? [1] : []
      content {
        name  = "require_secure_transport"
        value = "on"
      }
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database_instance" "same_region_replica" {
  provider             = google-beta
  name                 = "prod-sql-replica-local"
  database_version     = var.database_version
  region               = var.region
  master_instance_name = google_sql_database_instance.primary.name
  deletion_protection  = var.deletion_protection

  settings {
    tier        = var.replica_tier
    disk_type   = "PD_SSD"
    user_labels = local.labels
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.sql.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_sql_database_instance" "cross_region_replica" {
  provider             = google-beta
  name                 = "prod-sql-replica-dr"
  database_version     = var.database_version
  region               = var.dr_region
  master_instance_name = google_sql_database_instance.primary.name
  deletion_protection  = var.deletion_protection

  settings {
    tier        = var.replica_tier
    disk_type   = "PD_SSD"
    user_labels = merge(local.labels, { role = "dr" })
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.sql.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
  }
}
