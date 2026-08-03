resource "google_monitoring_alert_policy" "p95_latency" {
  project      = var.project_id
  display_name = "${var.name_prefix} P95 latency > 200ms"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run P95 latency above 200ms"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 200
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }

  notification_channels = []
}

resource "google_monitoring_alert_policy" "error_rate" {
  project      = var.project_id
  display_name = "${var.name_prefix} Error rate > 5%"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run 5xx error rate above 5%"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" metric.label.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = []
}

resource "google_monitoring_alert_policy" "auth_spike" {
  project      = var.project_id
  display_name = "${var.name_prefix} 401 response spike"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run 401 responses spike"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" metric.label.response_code=\"401\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 20
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = []
}
