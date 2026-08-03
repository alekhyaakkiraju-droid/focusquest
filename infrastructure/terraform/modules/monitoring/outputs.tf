output "dashboard_name" {
  value = google_monitoring_dashboard.service_slo.id
}

output "log_bucket_id" {
  value = google_logging_project_bucket_config.audit_retention.bucket_id
}

output "alert_policy_names" {
  value = [
    google_monitoring_alert_policy.p95_latency.display_name,
    google_monitoring_alert_policy.error_rate.display_name,
    google_monitoring_alert_policy.auth_spike.display_name,
  ]
}
