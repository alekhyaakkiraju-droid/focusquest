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

variable "kms_key_id" {
  type = string
}

resource "google_storage_bucket" "avatars" {
  project  = var.project_id
  name     = "${var.name_prefix}-avatars"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = false

  encryption {
    default_kms_key_name = var.kms_key_id
  }

  cors {
    origin          = ["https://*.focusquest.app"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Cache-Control"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.avatars.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

output "bucket_name" {
  value = google_storage_bucket.avatars.name
}

output "bucket_url" {
  value = google_storage_bucket.avatars.url
}
