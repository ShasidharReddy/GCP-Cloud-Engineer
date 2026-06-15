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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

data "google_project" "current" {
  project_id = var.project_id
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  labels = {
    environment = "production"
    project     = "10-disaster-recovery"
    managed_by  = "terraform"
  }
  regions = [var.primary_region, var.secondary_region]
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "dns.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "servicenetworking.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "dr" {
  name                    = "dr-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "regional" {
  for_each = { for idx, region in local.regions : region => cidrsubnet(var.base_cidr, 4, idx) }

  name                     = "dr-${each.key}-subnet"
  region                   = each.key
  network                  = google_compute_network.dr.id
  ip_cidr_range            = each.value
  private_ip_google_access = true
}

resource "google_compute_health_check" "app" {
  name                = "dr-http-hc"
  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/healthz"
  }
}

resource "google_compute_instance_template" "app" {
  for_each = toset(local.regions)

  name_prefix  = "dr-${replace(each.key, "-", "")}-"
  machine_type = var.machine_type
  tags         = ["dr-app"]
  labels       = local.labels

  disk {
    boot         = true
    auto_delete  = true
    source_image = data.google_compute_image.debian.self_link
    disk_type    = "pd-balanced"
    disk_size_gb = 30
  }

  network_interface {
    subnetwork = google_compute_subnetwork.regional[each.key].id
  }

  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    apt-get update
    apt-get install -y nginx
    cat >/var/www/html/index.html <<HTML
    <html><body><h1>${each.key}</h1><p>DR workload ready.</p></body></html>
    HTML
    echo ok >/var/www/html/healthz
    sed -i 's/listen 80 default_server;/listen 8080 default_server;/' /etc/nginx/sites-available/default
    systemctl restart nginx
  EOT

  service_account {
    email  = var.runtime_service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "app" {
  for_each = toset(local.regions)

  name               = "dr-${each.key}-mig"
  region             = each.key
  base_instance_name = "dr-app"
  target_size        = each.key == var.primary_region ? var.primary_instance_count : var.secondary_instance_count

  version {
    instance_template = google_compute_instance_template.app[each.key].id
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app.id
    initial_delay_sec = 180
  }
}

resource "google_compute_backend_service" "app" {
  name                  = "dr-global-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.app.id]

  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.app
    content {
      group = backend.value.instance_group
    }
  }
}

resource "google_compute_url_map" "app" {
  name            = "dr-url-map"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  name    = "dr-http-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_address" "primary" {
  name = "dr-primary-ip"
}

resource "google_compute_global_forwarding_rule" "primary" {
  name                  = "dr-http-rule"
  target                = google_compute_target_http_proxy.app.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.primary.id
}

resource "google_compute_network" "sql" {
  name                    = "dr-sql-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_global_address" "sql_range" {
  name          = "dr-sql-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.sql.id
}

resource "google_service_networking_connection" "sql" {
  network                 = google_compute_network.sql.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_range.name]
}

resource "random_password" "db" {
  length  = 24
  special = true
}

resource "google_sql_database_instance" "primary" {
  provider            = google-beta
  name                = "dr-sql-primary"
  database_version    = "POSTGRES_16"
  region              = var.primary_region
  deletion_protection = true
  root_password       = random_password.db.result

  settings {
    tier                  = "db-custom-2-7680"
    availability_type     = "REGIONAL"
    user_labels           = local.labels
    connector_enforcement = "REQUIRED"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.sql.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }

  depends_on = [google_service_networking_connection.sql]
}

resource "google_sql_database_instance" "replica" {
  provider             = google-beta
  name                 = "dr-sql-replica"
  database_version     = "POSTGRES_16"
  region               = var.secondary_region
  master_instance_name = google_sql_database_instance.primary.name
  deletion_protection  = true

  replica_configuration {
    failover_target = false
  }

  settings {
    tier        = "db-custom-2-7680"
    user_labels = merge(local.labels, { role = "dr" })
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.sql.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_storage_bucket" "archive" {
  name                        = "${var.project_id}-dr-dual-region"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  labels                      = local.labels
  custom_placement_config {
    data_locations = [var.primary_region, var.secondary_region]
  }
}

resource "google_compute_resource_policy" "snapshots" {
  name   = "dr-snapshot-policy"
  region = var.primary_region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "03:00"
      }
    }

    retention_policy {
      max_retention_days    = 14
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
  }
}

resource "google_dns_managed_zone" "public" {
  name     = "dr-public-zone"
  dns_name = "${var.dns_zone_name}."
}

resource "google_dns_record_set" "app" {
  name         = "app.${google_dns_managed_zone.public.dns_name}"
  managed_zone = google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300

  routing_policy {
    health_check = google_compute_health_check.app.id

    primary_backup {
      trickle_ratio = 0.0

      primary {
        external_endpoints = [google_compute_global_address.primary.address]
      }

      backup_geo {
        location = var.secondary_region
        health_checked_targets {
          external_endpoints = [var.backup_endpoint_ip]
        }
      }
    }
  }
}

data "archive_file" "function_src" {
  type        = "zip"
  source_dir  = "${path.module}/function-source"
  output_path = "${path.module}/dr-function.zip"
}

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-dr-functions-src"
  location                    = "US"
  uniform_bucket_level_access = true
  labels                      = local.labels
}

resource "google_storage_bucket_object" "function_archive" {
  name   = "dr-function-${data.archive_file.function_src.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_src.output_path
}

resource "google_cloudfunctions2_function" "backup_orchestrator" {
  name        = "dr-backup-orchestrator"
  location    = var.primary_region
  description = "Manual backup and replica promotion helper"

  build_config {
    runtime     = "python311"
    entry_point = "orchestrate"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }

  service_config {
    available_memory                 = "256M"
    timeout_seconds                  = 60
    max_instance_count               = 2
    max_instance_request_concurrency = 20
    ingress_settings                 = "ALLOW_INTERNAL_ONLY"
    service_account_email            = var.runtime_service_account_email
    all_traffic_on_latest_revision   = true
    environment_variables = {
      PROJECT_ID       = var.project_id
      PRIMARY_INSTANCE = google_sql_database_instance.primary.name
      REPLICA_INSTANCE = google_sql_database_instance.replica.name
    }
  }
}
