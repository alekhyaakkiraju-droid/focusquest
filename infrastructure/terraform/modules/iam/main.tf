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

variable "service_accounts" {
  type = list(string)
}

locals {
  role_bindings = {
    "auth-service" = [
      "roles/cloudsql.client",
      "roles/secretmanager.secretAccessor",
    ]
    "timer-service" = [
      "roles/cloudsql.client",
      "roles/redis.editor",
      "roles/pubsub.publisher",
    ]
    "quest-service" = [
      "roles/cloudsql.client",
      "roles/redis.editor",
      "roles/pubsub.publisher",
      "roles/pubsub.subscriber",
      "roles/storage.objectAdmin",
    ]
    "notification-service" = [
      "roles/pubsub.subscriber",
      "roles/secretmanager.secretAccessor",
    ]
    "compliance-service" = [
      "roles/cloudsql.client",
      "roles/pubsub.publisher",
      "roles/pubsub.subscriber",
    ]
    "analytics-service" = [
      "roles/cloudsql.client",
      "roles/redis.viewer",
    ]
    "api-gateway" = [
      "roles/run.invoker",
      "roles/cloudtrace.agent",
      "roles/logging.logWriter",
    ]
  }
}

resource "google_service_account" "services" {
  for_each = toset(var.service_accounts)

  project      = var.project_id
  account_id   = each.value
  display_name = "FocusQuest ${replace(each.value, "-", " ")}"
}

resource "google_project_iam_member" "service_roles" {
  for_each = {
    for binding in flatten([
      for account, roles in local.role_bindings : [
        for role in roles : {
          key     = "${account}-${replace(role, "/", "-")}"
          account = account
          role    = role
        }
      ]
    ]) : binding.key => binding
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.services[each.value.account].email}"
}

output "service_account_emails" {
  value = { for name, sa in google_service_account.services : name => sa.email }
}
