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
  project = var.host_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.host_project_id
  region  = var.region
}

data "google_project" "host" {
  project_id = var.host_project_id
}

data "google_project" "service" {
  for_each   = toset(var.service_project_ids)
  project_id = each.value
}

locals {
  labels = {
    environment = "production"
    project     = "04-vpc-shared-network"
    managed_by  = "terraform"
  }

  subnet_map = {
    for idx, project_id in var.service_project_ids : project_id => cidrsubnet(var.base_cidr, 4, idx)
  }

  network_user_members = [
    for p in data.google_project.service : "serviceAccount:${p.number}@cloudservices.gserviceaccount.com"
  ]
}

resource "google_project_service" "host_services" {
  for_each = toset([
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])

  project            = var.host_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "service_project_services" {
  for_each = toset(var.service_project_ids)

  project            = each.value
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  project    = var.host_project_id
  depends_on = [google_project_service.host_services]
}

resource "google_compute_shared_vpc_service_project" "service" {
  for_each        = toset(var.service_project_ids)
  host_project    = var.host_project_id
  service_project = each.value
  depends_on      = [google_compute_shared_vpc_host_project.host, google_project_service.service_project_services]
}

resource "google_compute_network" "hub" {
  name                    = "shared-hub-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "service" {
  for_each = local.subnet_map

  name                     = "subnet-${replace(each.key, "_", "-")}"
  region                   = var.region
  network                  = google_compute_network.hub.id
  ip_cidr_range            = each.value
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.7
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "nat" {
  name    = "shared-hub-router"
  region  = var.region
  network = google_compute_network.hub.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "shared-hub-nat"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "ingress" {
  name      = "shared-hub-ingress"
  network   = google_compute_network.hub.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.ingress_source_ranges
}

resource "google_compute_firewall" "egress" {
  name      = "shared-hub-egress"
  network   = google_compute_network.hub.name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_subnetwork_iam_binding" "network_user" {
  for_each = google_compute_subnetwork.service

  project    = var.host_project_id
  region     = var.region
  subnetwork = each.value.name
  role       = "roles/compute.networkUser"
  members    = local.network_user_members
}
