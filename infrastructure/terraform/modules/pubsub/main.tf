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

variable "topics" {
  type = list(string)
}

resource "google_pubsub_topic" "topics" {
  for_each = toset(var.topics)

  project = var.project_id
  name    = each.value

  message_storage_policy {
    allowed_persistence_regions = ["us-central1", "europe-west1"]
  }
}

output "topic_names" {
  value = [for topic in google_pubsub_topic.topics : topic.name]
}

output "topic_ids" {
  value = { for name, topic in google_pubsub_topic.topics : name => topic.id }
}
