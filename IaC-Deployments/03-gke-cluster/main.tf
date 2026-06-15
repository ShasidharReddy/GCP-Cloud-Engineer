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

data "google_client_config" "current" {}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

locals {
  labels = {
    environment = "production"
    project     = "03-gke-cluster"
    managed_by  = "terraform"
  }
  cluster_name = "prod-gke"
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "containeranalysis.googleapis.com",
    "binaryauthorization.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "gke" {
  name                    = "gke-private-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "gke" {
  name                     = "gke-private-subnet"
  region                   = var.region
  network                  = google_compute_network.gke.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "nat" {
  name    = "gke-router"
  region  = var.region
  network = google_compute_network.gke.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-nat"
  region                             = var.region
  router                             = google_compute_router.nat.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_container_cluster" "standard" {
  count    = var.enable_autopilot ? 0 : 1
  provider = google-beta

  name       = local.cluster_name
  location   = var.region
  network    = google_compute_network.gke.id
  subnetwork = google_compute_subnetwork.gke.id

  release_channel {
    channel = "REGULAR"
  }

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection
  networking_mode          = "VPC_NATIVE"
  resource_labels          = local.labels
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  depends_on = [google_compute_router_nat.nat]
}

resource "google_container_cluster" "autopilot" {
  count    = var.enable_autopilot ? 1 : 0
  provider = google-beta

  name                = "${local.cluster_name}-autopilot"
  location            = var.region
  enable_autopilot    = true
  network             = google_compute_network.gke.id
  subnetwork          = google_compute_subnetwork.gke.id
  deletion_protection = var.deletion_protection
  resource_labels     = local.labels

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  depends_on = [google_compute_router_nat.nat]
}

resource "google_container_node_pool" "default" {
  count    = var.enable_autopilot ? 0 : 1
  provider = google-beta

  name       = "default-pool"
  location   = var.region
  cluster    = google_container_cluster.standard[0].name
  node_count = 2

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.default_node_machine_type
    disk_type    = "pd-balanced"
    disk_size_gb = 100
    labels       = local.labels
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_container_node_pool" "highmem" {
  count    = var.enable_autopilot ? 0 : 1
  provider = google-beta

  name       = "highmem-pool"
  location   = var.region
  cluster    = google_container_cluster.standard[0].name
  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.highmem_node_machine_type
    disk_type    = "pd-balanced"
    disk_size_gb = 150
    labels       = merge(local.labels, { workload = "memory-optimized" })
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    taint {
      key    = "workload"
      value  = "memory"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "spot" {
  count    = var.enable_autopilot ? 0 : 1
  provider = google-beta

  name       = "spot-pool"
  location   = var.region
  cluster    = google_container_cluster.standard[0].name
  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.spot_node_machine_type
    disk_type    = "pd-balanced"
    disk_size_gb = 100
    spot         = true
    labels       = merge(local.labels, { pricing = "spot" })
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    taint {
      key    = "capacity"
      value  = "spot"
      effect = "NO_SCHEDULE"
    }
  }
}
