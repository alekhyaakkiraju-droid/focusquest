terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
}

variable "project_id" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "security_policy_id" {
  description = "Cloud Armor security policy attached to the backend service."
  type        = string
  default     = null
}

resource "google_compute_global_address" "gateway" {
  project = var.project_id
  name    = "${var.name_prefix}-gateway-ip"
}

resource "google_compute_health_check" "gateway" {
  project = var.project_id
  name    = "${var.name_prefix}-gateway-health"

  http_health_check {
    port         = 8080
    request_path = "/healthz"
  }
}

resource "google_compute_backend_service" "gateway" {
  project               = var.project_id
  name                  = "${var.name_prefix}-gateway-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.gateway.id]
  security_policy       = var.security_policy_id
}

resource "google_compute_url_map" "gateway" {
  project         = var.project_id
  name            = "${var.name_prefix}-gateway-url-map"
  default_service = google_compute_backend_service.gateway.id
}

resource "google_compute_target_http_proxy" "gateway" {
  project = var.project_id
  name    = "${var.name_prefix}-gateway-proxy"
  url_map = google_compute_url_map.gateway.id
}

resource "google_compute_global_forwarding_rule" "gateway" {
  project    = var.project_id
  name       = "${var.name_prefix}-gateway-forwarding-rule"
  target     = google_compute_target_http_proxy.gateway.id
  port_range = "80"
  ip_address = google_compute_global_address.gateway.address
}

output "backend_service_id" {
  value = google_compute_backend_service.gateway.id
}

output "gateway_ip" {
  value = google_compute_global_address.gateway.address
}
