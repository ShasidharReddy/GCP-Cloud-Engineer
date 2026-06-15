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
    project     = "08-monitoring-stack"
    managed_by  = "terraform"
  }
  dashboard_json = jsonencode({
    displayName = "Platform Operations"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Instance CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                    aggregation = {
                      perSeriesAligner = "ALIGN_MEAN"
                      alignmentPeriod  = "60s"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}

resource "google_project_service" "services" {
  for_each = toset([
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbilling.googleapis.com"
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Ops Email"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_notification_channel" "pagerduty" {
  display_name = "PagerDuty On-Call"
  type         = "pagerduty"
  labels = {
    service_name = var.pagerduty_service_name
  }
  sensitive_labels {
    service_key = var.pagerduty_service_key
  }
}

resource "google_monitoring_notification_channel" "slack" {
  display_name = "Slack Incidents"
  type         = "slack"
  labels = {
    channel_name = var.slack_channel_name
  }
  sensitive_labels {
    auth_token = var.slack_auth_token
  }
}

resource "google_monitoring_uptime_check_config" "public_health" {
  display_name = "Public HTTPS Health"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/healthz"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_host
    }
  }
}

resource "google_logging_metric" "error_rate" {
  name             = "application_error_rate"
  filter           = "resource.type=\"cloud_run_revision\" AND severity>=ERROR"
  label_extractors = {}
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels      = []
  }
}

resource "google_pubsub_topic" "logs" {
  name   = "observability-log-stream"
  labels = local.labels
}

resource "google_bigquery_dataset" "logs" {
  dataset_id                 = "central_logs"
  location                   = var.bigquery_location
  delete_contents_on_destroy = false
  labels                     = local.labels
}

resource "google_storage_bucket" "logs" {
  name                        = "${var.project_id}-observability-logs"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  labels                      = local.labels
}

resource "google_logging_project_sink" "bq" {
  name                   = "logs-to-bigquery"
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.logs.dataset_id}"
  filter                 = "logName:*"
  unique_writer_identity = true
}

resource "google_logging_project_sink" "gcs" {
  name                   = "logs-to-gcs"
  destination            = "storage.googleapis.com/${google_storage_bucket.logs.name}"
  filter                 = "severity>=ERROR"
  unique_writer_identity = true
}

resource "google_logging_project_sink" "pubsub" {
  name                   = "logs-to-pubsub"
  destination            = "pubsub.googleapis.com/projects/${var.project_id}/topics/${google_pubsub_topic.logs.name}"
  filter                 = "resource.type=\"cloud_run_revision\""
  unique_writer_identity = true
}

resource "google_monitoring_alert_policy" "cpu" {
  display_name = "High CPU Utilization"
  combiner     = "OR"
  notification_channels = [
    google_monitoring_notification_channel.email.id,
    google_monitoring_notification_channel.pagerduty.id,
    google_monitoring_notification_channel.slack.id
  ]

  conditions {
    display_name = "VM CPU above threshold"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "memory" {
  display_name          = "High Memory Utilization"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Guest memory above threshold"
    condition_threshold {
      filter          = "metric.type=\"agent.googleapis.com/memory/percent_used\""
      comparison      = "COMPARISON_GT"
      threshold_value = 90
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "error_rate" {
  display_name          = "Cloud Run error rate"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.pagerduty.id]

  conditions {
    display_name = "Error metric detected"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.error_rate.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"
    }
  }
}

resource "google_monitoring_alert_policy" "latency" {
  display_name          = "High request latency"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.slack.id]

  conditions {
    display_name = "Cloud Run p95 latency"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1000
      duration        = "300s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }
}

resource "google_monitoring_dashboard" "platform" {
  dashboard_json = local.dashboard_json
}

resource "google_monitoring_custom_service" "platform" {
  service_id   = "platform-slo"
  display_name = "Platform SLO Service"
}

resource "google_monitoring_slo" "availability" {
  service             = google_monitoring_custom_service.platform.service_id
  slo_id              = "availability-slo"
  display_name        = "Monthly availability 99.9%"
  goal                = 0.999
  rolling_period_days = 30

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"run.googleapis.com/request_latencies\""
      range {
        max = 1000
      }
    }
  }
}

resource "google_billing_budget" "project" {
  billing_account = var.billing_account_id
  display_name    = "Project budget"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.name]
  }
}
