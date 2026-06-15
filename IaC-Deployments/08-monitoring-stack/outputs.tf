output "notification_channels" {
  description = "Monitoring notification channel identifiers."
  value = {
    email     = google_monitoring_notification_channel.email.id
    pagerduty = google_monitoring_notification_channel.pagerduty.id
    slack     = google_monitoring_notification_channel.slack.id
  }
}

output "dashboard_name" {
  description = "Resource name of the custom monitoring dashboard."
  value       = google_monitoring_dashboard.platform.id
}

output "log_sinks" {
  description = "Central log sink names for analytics, archival, and streaming."
  value = [
    google_logging_project_sink.bq.name,
    google_logging_project_sink.gcs.name,
    google_logging_project_sink.pubsub.name
  ]
}
