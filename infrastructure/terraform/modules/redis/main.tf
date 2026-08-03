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

variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vpc_network_id" {
  type = string
}

variable "transit_encryption_mode" {
  type    = string
  default = "SERVER_AUTHENTICATION"
}

resource "google_redis_instance" "cache" {
  project                 = var.project_id
  name                    = "${var.name_prefix}-redis"
  tier                    = "STANDARD_HA"
  memory_size_gb          = 1
  region                  = var.region
  location_id             = "${var.region}-a"
  authorized_network      = var.vpc_network_id
  transit_encryption_mode = var.transit_encryption_mode
  redis_version           = "REDIS_7_0"
}

output "instance_name" {
  value = google_redis_instance.cache.name
}

output "host" {
  value = google_redis_instance.cache.host
}
