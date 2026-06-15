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

locals {
  labels = {
    environment = "production"
    project     = "06-cloud-run-lb"
    managed_by  = "terraform"
  }
  region_map = { for region in var.regions : region => region }
}

resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "vpcaccess.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "run" {
  account_id   = "cloud-run-runtime"
  display_name = "Cloud Run runtime service account"
}

resource "google_artifact_registry_repository" "app" {
  provider      = google-beta
  location      = var.regions[0]
  repository_id = "cloud-run-apps"
  format        = "DOCKER"
  labels        = local.labels
}

resource "google_compute_network" "serverless" {
  name                    = "cloud-run-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "connector" {
  for_each = local.region_map

  name                     = "run-connector-${each.key}"
  region                   = each.key
  network                  = google_compute_network.serverless.id
  ip_cidr_range            = cidrsubnet(var.base_cidr, 4, index(var.regions, each.key))
  private_ip_google_access = true
}

resource "google_vpc_access_connector" "connector" {
  for_each = local.region_map

  name          = "run-${replace(each.key, "-", "")}-connector"
  region        = each.key
  network       = google_compute_network.serverless.name
  ip_cidr_range = cidrsubnet(var.connector_cidr, 4, index(var.regions, each.key))
  min_instances = 2
  max_instances = 3
}

resource "google_cloud_run_v2_service" "app" {
  for_each = local.region_map
  provider = google-beta

  name                = "app-${each.key}"
  location            = each.key
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false
  labels              = local.labels

  template {
    service_account = google_service_account.run.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      connector = google_vpc_access_connector.connector[each.key].id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.container_image

      env {
        name  = "REGION"
        value = each.key
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = var.allow_unauthenticated ? local.region_map : {}
  provider = google-beta

  name     = google_cloud_run_v2_service.app[each.key].name
  location = each.key
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  for_each = local.region_map
  provider = google-beta

  name                  = "neg-${replace(each.key, "-", "")}"
  network_endpoint_type = "SERVERLESS"
  region                = each.key

  cloud_run {
    service = google_cloud_run_v2_service.app[each.key].name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_security_policy" "armor" {
  name = "cloud-run-waf"

  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow after higher priority deny rules"
  }

  rule {
    action   = "deny(403)"
    priority = "900"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable') || evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block common SQLi and XSS signatures"
  }
}

resource "google_compute_backend_service" "app" {
  name                  = "cloud-run-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  enable_cdn            = true
  security_policy       = google_compute_security_policy.armor.id

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.serverless_neg
    content {
      group = backend.value.id
    }
  }
}

resource "google_compute_url_map" "app" {
  name            = "cloud-run-url-map"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_managed_ssl_certificate" "cert" {
  name = "cloud-run-cert"
  managed {
    domains = var.domains
  }
}

resource "google_compute_target_https_proxy" "app" {
  name             = "cloud-run-https-proxy"
  url_map          = google_compute_url_map.app.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

resource "google_compute_global_address" "lb" {
  name = "cloud-run-lb-ip"
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "cloud-run-https-rule"
  target                = google_compute_target_https_proxy.app.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
}
