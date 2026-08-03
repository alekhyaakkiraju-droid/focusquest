terraform {
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.40"
    }
  }
}

variable "org_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "access_policy_title" {
  type = string
}

variable "perimeter_name" {
  type = string
}

variable "restricted_services" {
  type = list(string)
}

resource "google_access_context_manager_access_policy" "policy" {
  provider = google-beta
  parent   = "organizations/${var.org_id}"
  title    = var.access_policy_title
}

resource "google_access_context_manager_service_perimeter" "perimeter" {
  provider = google-beta
  parent   = "accessPolicies/${google_access_context_manager_access_policy.policy.name}"
  name     = "accessPolicies/${google_access_context_manager_access_policy.policy.name}/servicePerimeters/${var.perimeter_name}"
  title    = var.perimeter_name

  status {
    restricted_services = var.restricted_services
    resources           = ["projects/${var.project_id}"]
  }

  spec {
    access_levels = []
  }
}

output "perimeter_name" {
  value = google_access_context_manager_service_perimeter.perimeter.name
}

output "access_policy_name" {
  value = google_access_context_manager_access_policy.policy.name
}
