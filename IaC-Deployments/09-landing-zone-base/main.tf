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
  billing_project = var.bootstrap_project_id
}

provider "google-beta" {
  billing_project = var.bootstrap_project_id
}

locals {
  labels = {
    environment = "production"
    project     = "09-landing-zone-base"
    managed_by  = "terraform"
  }
}

resource "google_folder" "bootstrap" {
  display_name = "Bootstrap"
  parent       = "organizations/${var.organization_id}"
}

resource "google_folder" "common" {
  display_name = "Common"
  parent       = "organizations/${var.organization_id}"
}

resource "google_folder" "production" {
  display_name = "Production"
  parent       = "organizations/${var.organization_id}"
}

resource "google_folder" "nonproduction" {
  display_name = "Non-Production"
  parent       = "organizations/${var.organization_id}"
}

resource "google_folder" "sandbox" {
  display_name = "Sandbox"
  parent       = "organizations/${var.organization_id}"
}

resource "google_project" "bootstrap" {
  project_id      = var.bootstrap_project_id
  name            = "bootstrap-admin"
  folder_id       = google_folder.bootstrap.folder_id
  billing_account = var.billing_account_id
  labels          = local.labels
}

resource "google_project" "shared_vpc" {
  project_id      = var.shared_vpc_project_id
  name            = "shared-vpc-common"
  folder_id       = google_folder.common.folder_id
  billing_account = var.billing_account_id
  labels          = local.labels
}

resource "google_project" "logging" {
  project_id      = var.logging_project_id
  name            = "central-logging"
  folder_id       = google_folder.common.folder_id
  billing_account = var.billing_account_id
  labels          = local.labels
}

resource "google_project" "prod_app" {
  project_id      = var.production_project_id
  name            = "prod-app"
  folder_id       = google_folder.production.folder_id
  billing_account = var.billing_account_id
  labels          = local.labels
}

resource "google_project" "nonprod_app" {
  project_id      = var.nonproduction_project_id
  name            = "nonprod-app"
  folder_id       = google_folder.nonproduction.folder_id
  billing_account = var.billing_account_id
  labels          = local.labels
}

resource "google_project" "sandbox" {
  project_id      = var.sandbox_project_id
  name            = "sandbox-app"
  folder_id       = google_folder.sandbox.folder_id
  billing_account = var.billing_account_id
  labels          = local.labels
}

resource "google_project_service" "common_services" {
  for_each = toset([
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ])

  project            = google_project.shared_vpc.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = google_project.shared_vpc.project_id
}

resource "google_compute_network" "shared" {
  project                 = google_project.shared_vpc.project_id
  name                    = "common-shared-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "prod" {
  project                  = google_project.shared_vpc.project_id
  name                     = "prod-shared-subnet"
  region                   = var.default_region
  network                  = google_compute_network.shared.id
  ip_cidr_range            = "10.90.0.0/20"
  private_ip_google_access = true
}

resource "google_org_policy_policy" "domain_restricted" {
  name   = "organizations/${var.organization_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.organization_id}"
  spec {
    rules {
      values {
        allowed_values = ["customers/${var.customer_id}"]
      }
    }
  }
}

resource "google_org_policy_policy" "bucket_access" {
  name   = "organizations/${var.organization_id}/policies/storage.uniformBucketLevelAccess"
  parent = "organizations/${var.organization_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "disable_serial_port" {
  name   = "organizations/${var.organization_id}/policies/compute.disableSerialPortAccess"
  parent = "organizations/${var.organization_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "vm_external_ip" {
  name   = "organizations/${var.organization_id}/policies/compute.vmExternalIpAccess"
  parent = "organizations/${var.organization_id}"
  spec {
    rules {
      deny_all = true
    }
  }
}

resource "google_organization_iam_member" "org_viewer" {
  org_id = var.organization_id
  role   = "roles/resourcemanager.organizationViewer"
  member = var.platform_admin_member
}

resource "google_folder_iam_member" "common_admin" {
  folder = google_folder.common.name
  role   = "roles/resourcemanager.folderAdmin"
  member = var.platform_admin_member
}

resource "google_project_iam_member" "logging_admin" {
  project = google_project.logging.project_id
  role    = "roles/logging.admin"
  member  = var.platform_admin_member
}

resource "google_essential_contacts_contact" "security" {
  parent                              = "organizations/${var.organization_id}"
  email                               = var.essential_contact_email
  language_tag                        = "en-US"
  notification_category_subscriptions = ["SECURITY", "TECHNICAL", "SUSPENSION"]
}

resource "google_billing_budget" "org" {
  billing_account = var.billing_account_id
  display_name    = "Organization bootstrap budget"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }
}
