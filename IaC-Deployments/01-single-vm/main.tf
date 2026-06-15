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
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_project" "current" {
  project_id = var.project_id
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

locals {
  deployment_name = "single-vm"
  labels = {
    environment = "production"
    project     = "01-single-vm"
    managed_by  = "terraform"
  }

  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    apt-get update
    apt-get install -y nginx jq google-cloud-ops-agent
    systemctl enable nginx
    cat >/var/www/html/index.html <<HTML
    <html>
      <body>
        <h1>01-single-vm</h1>
        <p>Project: ${data.google_project.current.project_id}</p>
        <p>Zone: ${var.zone}</p>
      </body>
    </html>
    HTML
    systemctl restart nginx
  EOT
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "${local.deployment_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${local.deployment_name}-subnet"
  ip_cidr_range            = var.network_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name        = "${local.deployment_name}-allow-ssh"
  network     = google_compute_network.vpc.name
  target_tags = var.tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "allow_http" {
  name        = "${local.deployment_name}-allow-http"
  network     = google_compute_network.vpc.name
  target_tags = var.tags

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_icmp" {
  name        = "${local.deployment_name}-allow-icmp"
  network     = google_compute_network.vpc.name
  target_tags = var.tags

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "vm" {
  account_id   = "single-vm-sa"
  display_name = "Single VM runtime service account"
}

resource "google_project_iam_member" "vm_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_compute_address" "static_ip" {
  name   = "${local.deployment_name}-public-ip"
  region = var.region
}

resource "google_compute_disk" "data" {
  name   = "${local.deployment_name}-data"
  type   = "pd-ssd"
  zone   = var.zone
  size   = var.disk_size_gb
  labels = local.labels
}

resource "google_compute_instance" "vm" {
  name         = "${local.deployment_name}-01"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags
  labels       = local.labels

  boot_disk {
    auto_delete = true
    initialize_params {
      image  = data.google_compute_image.ubuntu.self_link
      type   = "pd-ssd"
      size   = 30
      labels = local.labels
    }
  }

  attached_disk {
    source      = google_compute_disk.data.id
    device_name = "data-ssd"
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata_startup_script   = local.startup_script
  allow_stopping_for_update = true

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [google_project_iam_member.vm_roles]
}
