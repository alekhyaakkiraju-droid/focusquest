locals {
  name_prefix = "focusquest-${var.environment}"
  regions     = toset(var.regions)
}

resource "google_project" "focusquest" {
  name            = "FocusQuest ${title(var.environment)}"
  project_id      = var.project_id
  org_id          = var.org_id
  billing_account = var.billing_account

  labels = {
    application = "focusquest"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "cloudkms.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project = google_project.focusquest.project_id
  service = each.value

  disable_on_destroy = false
}

module "kms" {
  source = "./modules/kms"

  project_id  = google_project.focusquest.project_id
  name_prefix = local.name_prefix
  regions     = var.regions

  depends_on = [google_project_service.required_apis]
}

module "vpc" {
  for_each = local.regions
  source   = "./modules/vpc"

  project_id  = google_project.focusquest.project_id
  region      = each.value
  name_prefix = "${local.name_prefix}-${replace(each.value, "-", "")}"

  depends_on = [google_project_service.required_apis]
}

module "cloudsql" {
  for_each = local.regions
  source   = "./modules/cloudsql"

  project_id             = google_project.focusquest.project_id
  region                 = each.value
  name_prefix            = "${local.name_prefix}-${replace(each.value, "-", "")}"
  vpc_network_id         = module.vpc[each.value].network_id
  kms_key_id             = module.kms.regional_keys[each.value].id
  private_vpc_connection = module.vpc[each.value].private_vpc_connection

  depends_on = [module.kms, module.vpc]
}

module "redis" {
  for_each = local.regions
  source   = "./modules/redis"

  project_id              = google_project.focusquest.project_id
  region                  = each.value
  name_prefix             = "${local.name_prefix}-${replace(each.value, "-", "")}"
  vpc_network_id          = module.vpc[each.value].network_id
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  depends_on = [module.vpc]
}

module "pubsub" {
  source = "./modules/pubsub"

  project_id  = google_project.focusquest.project_id
  name_prefix = local.name_prefix
  topics      = var.pubsub_topics

  depends_on = [google_project_service.required_apis]
}

module "storage" {
  for_each = local.regions
  source   = "./modules/storage"

  project_id  = google_project.focusquest.project_id
  region      = each.value
  name_prefix = "${local.name_prefix}-${replace(each.value, "-", "")}"
  kms_key_id  = module.kms.regional_keys[each.value].id

  depends_on = [module.kms, google_project_service.required_apis]
}

module "iam" {
  source = "./modules/iam"

  project_id       = google_project.focusquest.project_id
  service_accounts = var.service_accounts

  depends_on = [google_project_service.required_apis]
}

module "cloud_armor" {
  source = "./modules/cloud_armor"

  project_id  = google_project.focusquest.project_id
  name_prefix = local.name_prefix

  depends_on = [google_project_service.required_apis]
}

module "load_balancer" {
  source = "./modules/load_balancer"

  project_id         = google_project.focusquest.project_id
  name_prefix        = local.name_prefix
  region             = var.primary_region
  security_policy_id = module.cloud_armor.security_policy_id

  depends_on = [google_project_service.required_apis, module.cloud_armor]
}

module "vpc_service_controls" {
  source = "./modules/vpc_service_controls"

  org_id              = var.org_id
  project_id          = google_project.focusquest.project_id
  access_policy_title = var.access_policy_title
  perimeter_name      = var.vpc_sc_perimeter_name
  restricted_services = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "pubsub.googleapis.com",
    "cloudkms.googleapis.com",
  ]

  depends_on = [google_project_service.required_apis]
}
