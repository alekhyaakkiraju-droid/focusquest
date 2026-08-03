variable "project_id" {
  description = "GCP project ID for FocusQuest infrastructure."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID linked to the GCP project."
  type        = string
}

variable "org_id" {
  description = "GCP organization ID used for project creation and VPC Service Controls."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (dev, staging, production)."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging, or production."
  }
}

variable "primary_region" {
  description = "Primary GCP region for shared resources."
  type        = string
  default     = "us-central1"
}

variable "regions" {
  description = "Dual-region deployment targets for data residency isolation."
  type        = list(string)
  default     = ["us-central1", "europe-west1"]
}

variable "pubsub_topics" {
  description = "Inter-service Pub/Sub topics."
  type        = list(string)
  default = [
    "session-completed",
    "quest-progress",
    "xp-awarded",
    "notification-send",
    "consent-recorded",
    "data-deletion-requested",
  ]
}

variable "service_accounts" {
  description = "Per-service IAM service accounts with least-privilege roles."
  type        = list(string)
  default = [
    "auth-service",
    "timer-service",
    "quest-service",
    "notification-service",
    "compliance-service",
    "analytics-service",
    "api-gateway",
  ]
}

variable "access_policy_title" {
  description = "Title for the VPC Service Controls access policy."
  type        = string
  default     = "focusquest-access-policy"
}

variable "vpc_sc_perimeter_name" {
  description = "Name of the VPC Service Controls service perimeter."
  type        = string
  default     = "focusquest-core-perimeter"
}

variable "terraform_state_bucket" {
  description = "Optional GCS bucket for remote Terraform state."
  type        = string
  default     = ""
}
