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

data "google_compute_zones" "regional" {
  for_each = toset(var.regions)
  project  = var.project_id
  region   = each.value
  status   = "UP"
}

locals {
  labels = {
    environment = "production"
    project     = "02-multi-region-ha"
    managed_by  = "terraform"
  }

  region_map = {
    for idx, region in var.regions : region => {
      subnet_cidr = cidrsubnet(var.network_cidr, 4, idx)
    }
  }
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "storagetransfer.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "ha" {
  name                    = "multi-region-ha-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "regional" {
  for_each = local.region_map

  name                     = "ha-${each.key}-subnet"
  ip_cidr_range            = each.value.subnet_cidr
  region                   = each.key
  network                  = google_compute_network.ha.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "http" {
  name        = "ha-allow-http"
  network     = google_compute_network.ha.name
  target_tags = ["ha-web"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

resource "google_compute_health_check" "http" {
  name                = "ha-http-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/healthz"
  }
}

resource "google_compute_instance_template" "web" {
  for_each = local.region_map

  name_prefix  = "ha-${replace(each.key, "-", "")}-"
  machine_type = var.machine_type
  tags         = ["ha-web"]
  labels       = local.labels

  disk {
    auto_delete  = true
    boot         = true
    source_image = data.google_compute_image.debian.self_link
    disk_type    = "pd-balanced"
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = google_compute_subnetwork.regional[each.key].id
  }

  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    apt-get update
    apt-get install -y nginx jq
    cat >/var/www/html/index.html <<HTML
    <html><body><h1>${each.key}</h1><p>Served by Terraform HA stack.</p></body></html>
    HTML
    cat >/var/www/html/healthz <<HTML
    ok
    HTML
    sed -i 's/listen 80 default_server;/listen 8080 default_server;/' /etc/nginx/sites-available/default
    systemctl restart nginx
  EOT

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "mig" {
  for_each = local.region_map

  name               = "ha-${each.key}-mig"
  region             = each.key
  base_instance_name = "ha-web"
  target_size        = var.instance_count

  distribution_policy_zones = slice(data.google_compute_zones.regional[each.key].names, 0, min(2, length(data.google_compute_zones.regional[each.key].names)))

  version {
    instance_template = google_compute_instance_template.web[each.key].id
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http.id
    initial_delay_sec = 180
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  for_each = local.region_map

  name   = "ha-${each.key}-autoscaler"
  region = each.key
  target = google_compute_region_instance_group_manager.mig[each.key].id

  autoscaling_policy {
    min_replicas    = var.instance_count
    max_replicas    = var.instance_count + 3
    cooldown_period = 60

    cpu_utilization {
      target = 0.65
    }
  }
}

resource "google_compute_backend_service" "global" {
  name                  = "ha-global-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = true
  health_checks         = [google_compute_health_check.http.id]

  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.mig
    content {
      group           = backend.value.instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  }
}

resource "google_compute_url_map" "https" {
  name            = "ha-url-map"
  default_service = google_compute_backend_service.global.id
}

resource "google_compute_managed_ssl_certificate" "cert" {
  name = "ha-managed-cert"
  managed {
    domains = var.domains
  }
}

resource "google_compute_target_https_proxy" "https" {
  name             = "ha-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

resource "google_compute_global_address" "lb" {
  name = "ha-global-ip"
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "ha-https-forwarding-rule"
  target                = google_compute_target_https_proxy.https.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
}

resource "google_storage_bucket" "origin" {
  name                        = "${var.project_id}-ha-origin"
  location                    = var.regions[0]
  uniform_bucket_level_access = true
  labels                      = local.labels
  versioning { enabled = true }
}

resource "google_storage_bucket" "replica" {
  name                        = "${var.project_id}-ha-replica"
  location                    = var.regions[1]
  uniform_bucket_level_access = true
  labels                      = local.labels
  versioning { enabled = true }
}

resource "google_storage_transfer_job" "replication" {
  description = "Cross-region replication from origin to replica bucket"
  project     = var.project_id

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.origin.name
    }
    gcs_data_sink {
      bucket_name = google_storage_bucket.replica.name
    }
    transfer_options {
      delete_objects_unique_in_sink              = false
      overwrite_objects_already_existing_in_sink = false
    }
  }

  schedule {
    schedule_start_date {
      year  = 2026
      month = 1
      day   = 1
    }
    schedule_end_date {
      year  = 2035
      month = 12
      day   = 31
    }
    start_time_of_day {
      hours   = 0
      minutes = 30
      seconds = 0
      nanos   = 0
    }
  }
}
