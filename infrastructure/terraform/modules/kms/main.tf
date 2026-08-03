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

variable "regions" {
  type = list(string)
}

locals {
  regions = toset(var.regions)
}

resource "google_kms_key_ring" "regional" {
  for_each = local.regions

  project  = var.project_id
  name     = "${var.name_prefix}-${replace(each.value, "-", "")}-keyring"
  location = each.value
}

resource "google_kms_crypto_key" "cloudsql" {
  for_each = local.regions

  name            = "${var.name_prefix}-${replace(each.value, "-", "")}-cloudsql-key"
  key_ring        = google_kms_key_ring.regional[each.value].id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

output "regional_keys" {
  value = google_kms_crypto_key.cloudsql
}

output "keyring_names" {
  value = { for region, keyring in google_kms_key_ring.regional : region => keyring.name }
}
